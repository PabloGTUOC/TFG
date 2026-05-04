export const HOUSEHOLD_ACTIVITIES = [
  { title: 'Breakfast prep', category: 'household', duration: 20, recurrent: true },
  { title: 'Lunch prep', category: 'household', duration: 30, recurrent: true },
  { title: 'Dinner prep', category: 'household', duration: 45, recurrent: true },
  { title: 'Grocery shopping', category: 'household', duration: 60, recurrent: false },
  { title: 'Laundry', category: 'household', duration: 30, recurrent: false },
  { title: 'House cleaning', category: 'household', duration: 60, recurrent: false },
  { title: 'Dishes / kitchen cleanup', category: 'household', duration: 20, recurrent: true },
];

export const CHILD_ACTIVITIES = [
  { title: 'Morning routine', category: 'care', duration: 45, recurrent: true },
  { title: 'Daycare / school drop-off', category: 'care', duration: 30, recurrent: true },
  { title: 'Daycare / school pick-up', category: 'care', duration: 30, recurrent: true },
  { title: 'Nap time supervision', category: 'care', duration: 90, recurrent: true },
  { title: 'Outdoor play / park', category: 'care', duration: 60, recurrent: true },
  { title: 'Bath time', category: 'care', duration: 30, recurrent: true },
  { title: 'Bedtime routine', category: 'care', duration: 45, recurrent: true },
  { title: 'Night wake-up', category: 'care', duration: 30, recurrent: false },
  { title: 'Homework help', category: 'care', duration: 45, recurrent: true },
];

export const PET_ACTIVITIES = [
  { title: 'Morning walk', category: 'care', duration: 30, recurrent: true },
  { title: 'Evening walk', category: 'care', duration: 30, recurrent: true },
  { title: 'Pet feeding', category: 'care', duration: 15, recurrent: true },
];

export const GENERIC_CARE_ACTIVITIES = [
  { title: 'Doctor / appointment accompany', category: 'care', duration: 90, recurrent: false },
  { title: 'Medication reminder', category: 'care', duration: 15, recurrent: true },
];

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
      act.duration, // Set coin_value equal to duration automatically
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
