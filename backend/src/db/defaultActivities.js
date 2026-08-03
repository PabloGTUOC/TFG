export const HOUSEHOLD_ACTIVITIES = [
  { title: 'Breakfast prep', category: 'household', duration: 30, recurrent: true },
  { title: 'Lunch prep', category: 'household', duration: 30, recurrent: true },
  { title: 'Dinner prep', category: 'household', duration: 60, recurrent: true },
  { title: 'Grocery shopping', category: 'household', duration: 60, recurrent: false },
  { title: 'Laundry', category: 'household', duration: 30, recurrent: false },
  { title: 'House cleaning', category: 'household', duration: 60, recurrent: false },
  { title: 'Dishes / kitchen cleanup', category: 'household', duration: 30, recurrent: true },
];

export const CHILD_ACTIVITIES = [
  { title: 'Morning routine', category: 'care', duration: 60, recurrent: true },
  { title: 'Daycare / school drop-off', category: 'care', duration: 30, recurrent: true },
  { title: 'Daycare / school pick-up', category: 'care', duration: 30, recurrent: true },
  { title: 'Nap time supervision', category: 'care', duration: 90, recurrent: true },
  { title: 'Outdoor play / park', category: 'care', duration: 60, recurrent: true },
  { title: 'Bath time', category: 'care', duration: 30, recurrent: true },
  { title: 'Bedtime routine', category: 'care', duration: 60, recurrent: true },
  { title: 'Night wake-up', category: 'care', duration: 30, recurrent: false },
  { title: 'Homework help', category: 'care', duration: 60, recurrent: true },
];

export const PET_ACTIVITIES = [
  { title: 'Morning walk', category: 'care', duration: 30, recurrent: true },
  { title: 'Evening walk', category: 'care', duration: 30, recurrent: true },
  { title: 'Pet feeding', category: 'care', duration: 30, recurrent: true },
];

export const GENERIC_CARE_ACTIVITIES = [
  { title: 'Doctor / appointment accompany', category: 'care', duration: 90, recurrent: false },
  { title: 'Medication reminder', category: 'care', duration: 30, recurrent: true },
];

// ── Client-supplied starter tasks (docs/family-setup-questionnaire-plan.md) ──
//
// New clients build a localized catalogue from lib/data/starter_packs.dart and
// send it at family creation, so a Spanish family is seeded in Spanish. The
// arrays above remain the fallback for clients that omit the field.

const MAX_STARTER_TASKS = 40;
const STARTER_CATEGORIES = ['care', 'household'];
// Mirrors the activities table CHECK (duration_minutes >= 15).
const MIN_DURATION_MINUTES = 15;

/**
 * Validates a client-supplied starter catalogue. These rows go straight into
 * `activities`, so they are checked like any other user input — otherwise a
 * malformed payload trips a DB constraint and surfaces as a 500.
 * Returns an error message, or null when the list is usable.
 */
export function validateStarterTasks(tasks) {
  if (!Array.isArray(tasks)) return 'starterTasks must be an array.';
  if (tasks.length > MAX_STARTER_TASKS) {
    return `starterTasks must contain at most ${MAX_STARTER_TASKS} items.`;
  }
  for (const [i, task] of tasks.entries()) {
    if (!task || typeof task !== 'object') return `starterTasks[${i}]: must be an object.`;
    const title = typeof task.title === 'string' ? task.title.trim() : '';
    if (!title || title.length > 100) {
      return `starterTasks[${i}].title: must be 1-100 characters.`;
    }
    if (!STARTER_CATEGORIES.includes(task.category)) {
      return `starterTasks[${i}].category: must be one of: ${STARTER_CATEGORIES.join(', ')}.`;
    }
    const duration = Number(task.durationMinutes);
    if (!Number.isInteger(duration) || duration < MIN_DURATION_MINUTES) {
      return `starterTasks[${i}].durationMinutes: must be an integer >= ${MIN_DURATION_MINUTES}.`;
    }
    if (task.isRecurrent !== undefined && typeof task.isRecurrent !== 'boolean') {
      return `starterTasks[${i}].isRecurrent: must be a boolean.`;
    }
  }
  return null;
}

/**
 * Seeds the catalogue the client chose. Coin values follow the same rule the
 * activities screen suggests for user-created tasks — round(rate × hours),
 * floored at 1, where rate = monthlyCoinBudget / 720 — so the starter
 * catalogue is priced consistently with everything created afterwards.
 */
export async function insertStarterTasks(client, familyId, creatorId, tasks, monthlyCoinBudget) {
  if (!tasks.length) return;

  const baseRatePerHour = monthlyCoinBudget / 720;
  const values = [];
  const params = [];
  let paramIndex = 1;

  for (const task of tasks) {
    const duration = Number(task.durationMinutes);
    const coinValue = Math.max(1, Math.round((baseRatePerHour * duration) / 60));
    values.push(`($${paramIndex++}, $${paramIndex++}, $${paramIndex++}, $${paramIndex++}, $${paramIndex++}, $${paramIndex++}, $${paramIndex++}, 'approved', true)`);
    params.push(
      familyId,
      creatorId,
      task.title.trim(),
      task.category,
      duration,
      coinValue,
      task.isRecurrent === true
    );
  }

  await client.query(
    `INSERT INTO activities (
      family_id, created_by, title, category, duration_minutes, coin_value, is_recurrent, status, is_template
    ) VALUES ${values.join(', ')}`,
    params
  );
}

export async function insertDefaultActivities(client, familyId, creatorId, objectsOfCare) {
  // Always include household and generic care
  const activitiesToInsert = [...HOUSEHOLD_ACTIVITIES, ...GENERIC_CARE_ACTIVITIES];

  // Extract actor types passed from frontend
  const types = objectsOfCare.map(o => o.type?.toLowerCase() || o.actor_type?.toLowerCase() || '');
  
  if (types.includes('child') || types.includes('baby') || types.includes('toddler')) {
    activitiesToInsert.push(...CHILD_ACTIVITIES);
  }
  
  if (types.includes('pet') || types.includes('dog') || types.includes('cat')) {
    activitiesToInsert.push(...PET_ACTIVITIES);
  }

  if (activitiesToInsert.length === 0) return;

  // Build bulk insert query
  const values = [];
  const params = [];
  let paramIndex = 1;

  for (const act of activitiesToInsert) {
    values.push(`($${paramIndex++}, $${paramIndex++}, $${paramIndex++}, $${paramIndex++}, $${paramIndex++}, $${paramIndex++}, $${paramIndex++}, 'approved', true)`);
    params.push(
      familyId, 
      creatorId, 
      act.title, 
      act.category, 
      act.duration, 
      Math.max(1, Math.round((act.duration / 60) * 2)), // Default to 2 coins/hr
      act.recurrent
    );
  }

  const query = `
    INSERT INTO activities (
      family_id, created_by, title, category, duration_minutes, coin_value, is_recurrent, status, is_template
    ) VALUES ${values.join(', ')}
  `;

  await client.query(query, params);
}
