export async function assertActiveMember(client, familyId, userId) {
  const { rowCount } = await client.query(
    `SELECT 1 FROM family_members WHERE family_id = $1 AND user_id = $2 AND status = 'active'`,
    [familyId, userId]
  );
  return rowCount > 0;
}

export async function upsertUserFromAuth(client, auth) {
  // Update by firebase_uid first — handles returning users and email changes.
  const { rows: updated } = await client.query(
    `UPDATE users
     SET email        = COALESCE($2, email),
         display_name = COALESCE($3, display_name)
     WHERE firebase_uid = $1
     RETURNING id, firebase_uid, email, display_name, avatar_url`,
    [auth.uid, auth.email, auth.name]
  );
  if (updated.length) return updated[0];

  // New user — insert, handling the case where the email already exists
  // (e.g. an invited user signing up for the first time).
  const { rows } = await client.query(
    `INSERT INTO users (firebase_uid, email, display_name)
     VALUES ($1, $2, $3)
     ON CONFLICT (email)
     DO UPDATE SET firebase_uid  = EXCLUDED.firebase_uid,
                   display_name  = COALESCE(EXCLUDED.display_name, users.display_name)
     RETURNING id, firebase_uid, email, display_name, avatar_url`,
    [auth.uid, auth.email, auth.name]
  );
  return rows[0];
}
