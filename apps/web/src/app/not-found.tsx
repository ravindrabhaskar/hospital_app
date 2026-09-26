import Link from "next/link";

export default function NotFound() {
  return (
    <main id="main" className="grid min-h-screen place-items-center px-4">
      <div className="text-center">
        <p className="text-sm font-semibold text-primary-light">404</p>
        <h1 className="mt-1 text-2xl font-bold">Page not found</h1>
        <p className="mt-2 text-sm text-ink-muted">The page you are looking for does not exist.</p>
        <Link href="/" className="mt-4 inline-flex h-11 items-center rounded-full bg-primary px-5 text-sm font-semibold text-white">
          Go to the portal
        </Link>
      </div>
    </main>
  );
}
