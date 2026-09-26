import { loadConfig } from '../config.js';
import { createDb, runMigrations } from './client.js';

/** `npm run db:migrate` — apply pending migrations (the server also does this at startup). */
async function main(): Promise<void> {
  const config = loadConfig();
  const handle = await createDb({ databaseUrl: config.DATABASE_URL, pgliteDir: config.PGLITE_DIR });
  await runMigrations(handle);
  console.log(`Migrations applied (${handle.driver}).`);
  await handle.close();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
