import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { pool } from '../src/db/pool.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function main() {
  const schemaPath    = path.join(__dirname, '../src/db/schema.sql');
  const migrationPath = path.join(__dirname, 'migrate-deletion.sql');

  await pool.query(await fs.readFile(schemaPath, 'utf8'));
  console.log('Database schema initialized.');

  await pool.query(await fs.readFile(migrationPath, 'utf8'));
  console.log('Database migrations applied.');

  const fcmMigrationPath = path.join(__dirname, 'migrate-fcm.sql');
  await pool.query(await fs.readFile(fcmMigrationPath, 'utf8'));
  console.log('FCM token table ready.');

  const fcmIndexPath = path.join(__dirname, 'migrate-fcm-index.sql');
  await pool.query(await fs.readFile(fcmIndexPath, 'utf8'));
  console.log('FCM token index ready.');

  const notifPrefsPath = path.join(__dirname, 'migrate-notif-prefs.sql');
  await pool.query(await fs.readFile(notifPrefsPath, 'utf8'));
  console.log('Notification preferences table ready.');

  await pool.end();
}

main().catch((error) => {
  console.error('Failed to initialize database schema:', error);
  process.exitCode = 1;
});
