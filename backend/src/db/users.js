export async function upsertUserFromAuth(client, auth) {
  const { rows } = await client.query(
    `INSERT INTO users (firebase_uid, email, display_name)
     VALUES ($1, $2, $3)
     ON CONFLICT (firebase_uid)
     DO UPDATE SET email = EXCLUDED.email, display_name = EXCLUDED.display_name
     RETURNING id, firebase_uid, email, display_name`,
    [auth.uid, auth.email, auth.name]
  );

  return rows[0];
}
