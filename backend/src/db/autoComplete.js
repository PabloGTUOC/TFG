/**
 * Completes all approved activities whose end time has passed.
 * Must be called inside an existing transaction (client already has BEGIN).
 * Uses FOR UPDATE to prevent concurrent sweeps from double-awarding coins.
 */
export async function runAutoCompleteSweep(client, familyId) {
  const { rows: expired } = await client.query(
    `SELECT id, assigned_to, coin_value FROM activities
     WHERE family_id = $1 AND status = 'approved' AND ends_at <= NOW()
     FOR UPDATE`,
    [familyId]
  );

  for (const act of expired) {
    await client.query(
      `UPDATE activities SET status = 'completed', bounty_amount = 0, bounty_offered_by = NULL WHERE id = $1`,
      [act.id]
    );
    await client.query(
      `UPDATE family_members SET coin_balance = coin_balance + $1 WHERE family_id = $2 AND user_id = $3`,
      [act.coin_value, familyId, act.assigned_to]
    );
    await client.query(
      `INSERT INTO coin_ledger (family_id, user_id, activity_id, amount, reason)
       VALUES ($1, $2, $3, $4, 'activity_completed')`,
      [familyId, act.assigned_to, act.id, act.coin_value]
    );
  }
}
