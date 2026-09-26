import { buildApp } from './app.js';

async function main(): Promise<void> {
  const { app, svc } = await buildApp();
  const { HOST, PORT, API_PREFIX } = svc.config;
  const shutdown = async (signal: string) => {
    app.log.info({ signal }, 'shutting down');
    await app.close();
    process.exit(0);
  };
  process.on('SIGINT', () => void shutdown('SIGINT'));
  process.on('SIGTERM', () => void shutdown('SIGTERM'));
  await app.listen({ host: HOST, port: PORT });
  if (svc.config.REVIEW_PHONE && svc.config.REVIEW_OTP) {
    app.log.warn({ reviewPhone: svc.config.REVIEW_PHONE.slice(0, 5) + '…' }, 'App-store REVIEW login is ENABLED (fixed OTP for REVIEW_PHONE). Remove REVIEW_PHONE/REVIEW_OTP after review.');
  }
  const safety = await svc.safety.status();
  if (safety !== 'ok') {
    app.log.warn({ safetyRules: safety }, 'Safety rule pack is NOT clinician-approved (fixture or missing). Not for production use.');
  }
  app.log.info(
    { url: `http://localhost:${PORT}${API_PREFIX}`, db: svc.dbHandle.driver, ai: svc.ai.primary.name },
    'CareCompanion API ready',
  );
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
