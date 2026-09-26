import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    include: ['test/**/*.test.ts'],
    environment: 'node',
    testTimeout: 60_000,
    hookTimeout: 120_000,
    pool: 'forks',
    maxWorkers: 4,
    env: { NODE_ENV: 'test', LOG_LEVEL: 'silent' },
  },
});
