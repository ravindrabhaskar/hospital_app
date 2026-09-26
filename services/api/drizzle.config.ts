import { defineConfig } from 'drizzle-kit';

// Migrations are generated from src/db/schema.ts into ./drizzle and applied at startup
// by the matching drizzle migrator (node-postgres or PGlite). Never hand-edit the schema
// without generating a migration: `npm run db:generate`.
export default defineConfig({
  dialect: 'postgresql',
  schema: './src/db/schema.ts',
  out: './drizzle',
  strict: true,
  verbose: true,
});
