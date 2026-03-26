import pg from 'pg';
const { Client } = pg;
const client = new Client({ connectionString: 'postgres://carecoins:carecoins@localhost:5433/carecoins' });
async function test() {
  await client.connect();
  try {
    const res = await client.query(`
      INSERT INTO users (firebase_uid, email, display_name)
      VALUES ($1, $2, $3)
      ON CONFLICT (email)
      DO UPDATE SET firebase_uid = EXCLUDED.firebase_uid, display_name = EXCLUDED.display_name
      RETURNING id, firebase_uid, email, display_name`,
      ['test-uid-123', 'pbsitio@gmail.com', 'Test User']
    );
    console.log('SUCCESS:', res.rows);
  } catch (err) {
    console.error('DB ERROR:', err.message);
  } finally {
    await client.end();
  }
}
test();
