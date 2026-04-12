export async function upsertUserFromAuth(client, auth) {
  const { rows } = await client.query(
    `INSERT INTO users (firebase_uid, email, display_name)
     VALUES ($1, $2, $3)
     ON CONFLICT (email)
     DO UPDATE SET firebase_uid = EXCLUDED.firebase_uid, display_name = EXCLUDED.display_name
     RETURNING id, firebase_uid, email, display_name, avatar_url`,
    [auth.uid, auth.email, auth.name]
  );

  return rows[0];
}
