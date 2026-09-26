// Runs the Next.js standalone server (`output: "standalone"`), copying the static assets next to it
// first, as https://nextjs.org/docs/app/api-reference/config/next-config-js/output describes.
// Usage: npm run build && npm run start:standalone   (PORT and BIND_HOST env vars are honoured)
import { cpSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawn } from "node:child_process";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const standalone = join(root, ".next", "standalone");
const server = join(standalone, "server.js");

if (!existsSync(server)) {
  console.error("No standalone build found. Run `npm run build` first.");
  process.exit(1);
}

cpSync(join(root, ".next", "static"), join(standalone, ".next", "static"), { recursive: true });
if (existsSync(join(root, "public"))) cpSync(join(root, "public"), join(standalone, "public"), { recursive: true });

// HOSTNAME is often preset by shells/containers to the machine name, so the bind address comes from BIND_HOST.
const env = {
  ...process.env,
  NODE_ENV: "production",
  PORT: process.env.PORT ?? "3000",
  HOSTNAME: process.env.BIND_HOST ?? "0.0.0.0",
};
const child = spawn(process.execPath, [server], { stdio: "inherit", env, cwd: standalone });
const forward = (sig) => () => child.kill(sig);
process.on("SIGINT", forward("SIGINT"));
process.on("SIGTERM", forward("SIGTERM"));
child.on("exit", (code, signal) => process.exit(code ?? (signal ? 1 : 0)));
