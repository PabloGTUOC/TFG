/**
 * Monthly coin distribution — the second half of the CareCoins economy.
 *
 * A dependent generates one coin per hour of the month (`totalGdp`). Activities
 * completed that month claim part of it (`explicit`); whatever is left over
 * (`unclaimed`) is handed to the caregivers. Because `unclaimed` is the
 * remainder, logging an activity does not create coins — it moves them from the
 * shared residual to whoever did the work. See docs/personal-time-plan.md §1.2.
 *
 * The residual is split by *presence*: the coins for the hours a caregiver was
 * away go to whoever was home. See docs/personal-time-plan.md §3.1.
 *
 * The route triggers this on the first dashboard load of a new month, and every
 * elapsed month since the last run is settled in order.
 */

/** Advances a 'YYYY-MM' string by one month. */
function nextMonth(monthStr) {
  const [yearStr, monthNumStr] = monthStr.split('-');
  let year = parseInt(yearStr, 10);
  let month = parseInt(monthNumStr, 10) + 1;
  if (month > 12) { month = 1; year++; }
  return `${year}-${month.toString().padStart(2, '0')}`;
}

const MS_PER_HOUR = 3_600_000;

/**
 * Hours a caregiver was present during [monthStart, monthEnd).
 *
 * Absences are merged rather than summed, so two overlapping trips cannot
 * subtract the same hour twice, and a caregiver who joined mid-month only
 * counts from the day they joined.
 */
export function presentHours(monthStart, monthEnd, joinedAt, absences) {
  const from = Math.max(monthStart, joinedAt ?? monthStart);
  if (monthEnd <= from) return 0;

  const clipped = absences
    .map(({ start, end }) => [Math.max(from, start), Math.min(monthEnd, end)])
    .filter(([start, end]) => end > start)
    .sort((a, b) => a[0] - b[0]);

  let away = 0;
  let cursor = from;
  for (const [start, end] of clipped) {
    const uncounted = start > cursor ? start : cursor;
    if (end > uncounted) {
      away += end - uncounted;
      cursor = end;
    }
  }
  return Math.max(0, monthEnd - from - away) / MS_PER_HOUR;
}

/**
 * Splits `unclaimed` in proportion to `weights` — the hours each caregiver was
 * present. The coins for the hours you were away go to whoever was home
 * (docs/personal-time-plan.md §3.1); no consent is asked, because you cannot
 * decline your partner's business trip.
 *
 * Every share is floored and the rounding remainder is left unspent, exactly as
 * the even split always did, so the distribution can never invent a coin. When
 * nobody was present at all it falls back to an even split rather than
 * swallowing the residual.
 */
export function distributionShares(unclaimed, weights) {
  if (!weights.length || unclaimed <= 0) return weights.map(() => 0);
  const total = weights.reduce((sum, w) => sum + w, 0);
  if (total <= 0) {
    const even = Math.floor(unclaimed / weights.length);
    return weights.map(() => even);
  }
  return weights.map((w) => Math.floor((unclaimed * w) / total));
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
  // UTC bounds, matching the `explicit` query below, which buckets by UTC month.
  const monthStart = Date.UTC(year, month - 1, 1);
  const monthEnd = Date.UTC(year, month, 1);

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
    `SELECT id, user_id, joined_at FROM family_members WHERE family_id = $1 AND role = 'caregiver' AND status = 'active'`,
    [familyId]
  );

  if (caretakers.length === 0 || unclaimed <= 0) return;

  // A family has a handful of absences in a month, so they are merged in JS
  // rather than in SQL: the rule stays unit-testable, which a window function
  // over tstzranges would not be.
  const { rows: absenceRows } = await client.query(
    `SELECT user_id, start_time, end_time FROM absences
     WHERE family_id = $1 AND start_time < $3 AND end_time > $2`,
    [familyId, new Date(monthStart).toISOString(), new Date(monthEnd).toISOString()]
  );

  const weights = caretakers.map((c) => presentHours(
    monthStart,
    monthEnd,
    c.joined_at ? new Date(c.joined_at).getTime() : monthStart,
    absenceRows
      .filter((a) => String(a.user_id) === String(c.user_id))
      .map((a) => ({
        start: new Date(a.start_time).getTime(),
        end: new Date(a.end_time).getTime(),
      }))
  ));

  const shares = distributionShares(unclaimed, weights);

  for (const [i, c] of caretakers.entries()) {
    const share = shares[i];
    if (share <= 0) continue;
    await client.query(
      `UPDATE family_members SET coin_balance = coin_balance + $1 WHERE id = $2`,
      [share, c.id]
    );
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
