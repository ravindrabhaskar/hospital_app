import js from '@eslint/js';
import tseslint from 'typescript-eslint';

export default tseslint.config(
  { ignores: ['dist/**', 'node_modules/**', 'drizzle/**', '.data/**', 'coverage/**'] },
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    files: ['**/*.ts'],
    rules: {
      '@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_', varsIgnorePattern: '^_' }],
      '@typescript-eslint/no-explicit-any': 'off',
      '@typescript-eslint/no-non-null-assertion': 'off',
      'no-console': ['error', { allow: ['warn', 'error'] }],
    },
  },
  {
    files: ['src/db/seed.ts', 'src/db/migrate.ts', 'src/server.ts', 'src/scripts/**/*.ts', 'scripts/**/*.ts', 'src/modules/notifications/channels.ts', 'src/modules/auth/sms.ts'],
    rules: { 'no-console': 'off' },
  },
);
