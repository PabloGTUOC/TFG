/**
 * Monthly coin distribution — the second half of the CareCoins economy.
 *
 * A dependent generates one coin per hour of the month (`totalGdp`). Activities
 * completed that month claim part of it (`explicit`); whatever is left over
 * (`unclaimed`) is handed to the caregivers. Because `unclaimed` is the
 * remainder, logging an activity does not create coins — it moves them from the
 * shared residual to whoever did the work. See docs/personal-time-plan.md §1.2.
 *
 * Lifted out of routes/dashboard.js unchanged so the money path can be tested;
 * the route still triggers it on the first dashboard load of a new month, and
 * every elapsed month since the last run is settled in order.
 */

/** Advances a 'YYYY-MM' string by one month. */
function nextMonth(monthStr) {
  const [yearStr, monthNumStr] = monthStr.split('-');
  let year = parseInt(yearStr, 10);
  let month = parseInt(monthNumStr, 10) + 1;
  if (month > 12) { month = 1; year++; }
  return `${year}-${month.toString().padStart(2, '0')}`;
}

/**
 * Settles one elapsed month: works out what the dependents were worth, how much
 * of that was already claimed by completed activities, and hands the remainder
 * to the active caregivers.
 */
async function settleMonth(client, familyId, monthStr) {
  const [yearStr, monthNumStr] = monthStr.split('-');
  const year = parseInt(yearStr, 10);
  const month = parseInt(monthNumStr, 10);

  const daysInMonth = new Date(year, month, 0).getDate();
  const hoursInMonth = daysInMonth * 24;

  const { rows: careActors } = await client.query(
    `SELECT care_time FROM actors WHERE family_id = $1 AND actor_type != 'person'`,
    [familyId]
  );

  let totalGdp = 0;
  careActors.forEach(a => {
    totalGdp += (a.care_time === 'full_time' ? hoursInMonth : Math.floor(hoursInMonth / 2));
  });
  if (totalGdp <= 0) return;

  const { rows: explicit } = await client.query(
    `SELECT COALESCE(SUM(coin_value), 0)::int as total
     FROM activities
     WHERE family_id = $1
       AND status = 'completed'
       AND to_char(starts_at AT TIME ZONE 'UTC', 'YYYY-MM') = $2`,
    [familyId, monthStr]
  );

  const unclaimed = Math.max(0, totalGdp - explicit[0].total);

  const { rows: caretakers } = await client.query(
    `SELECT id, user_id FROM family_members WHERE family_id = $1 AND role = 'caregiver' AND status = 'active'`,
    [familyId]
  );

  if (caretakers.length === 0 || unclaimed <= 0) return;

  const share = Math.floor(unclaimed / caretakers.length);
  if (share <= 0) return;

  await client.query(
    `UPDATE family_members SET coin_balance = coin_balance + $1 WHERE id = ANY($2::bigint[])`,
    [share, caretakers.map(c => c.id)]
  );

  for (const c of caretakers) {
    await client.query(
      `INSERT INTO coin_ledger (family_id, user_id, amount, reason) VALUES ($1, $2, $3, 'monthly_distribution')`,
      [familyId, c.user_id, share]
    );
  }
}

/**
 * Brings a family's coin distribution up to date. Returns false when the family
 * does not exist, so the caller can 404/403 the way it always has. `now` is
 * injectable only so tests do not drift with the wall clock.
 *
 * Takes FOR UPDATE on the family row: two dashboard loads landing in the same
 * second must not both settle the same month.
 */
export async function runMonthlyDistribution(client, familyId, now = new Date()) {
  const familyRows = await client.query(
    'SELECT last_coin_distribution_month FROM families WHERE id = $1 FOR UPDATE',
    [familyId]
  );
  if (!familyRows.rowCount) return false;

  const lastMonth = familyRows.rows[0].last_coin_distribution_month;
  const currentMonthStr = now.toISOString().slice(0, 7);

  // A family that has never distributed starts its clock now rather than
  // back-paying every month since it was created.
  if (!lastMonth) {
    await client.query(
      'UPDATE families SET last_coin_distribution_month = $1 WHERE id = $2',
      [currentMonthStr, familyId]
    );
    return true;
  }

  if (lastMonth >= currentMonthStr) return true;

  for (let m = lastMonth; m < currentMonthStr; m = nextMonth(m)) {
    await settleMonth(client, familyId, m);
  }

  await client.query(
    'UPDATE families SET last_coin_distribution_month = $1 WHERE id = $2',
    [currentMonthStr, familyId]
  );
  return true;
}
