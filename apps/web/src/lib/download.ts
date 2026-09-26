/** Save a Blob fetched with auth as a file (object URL, revoked shortly after). */
export function saveBlob(blob: Blob, fileName: string) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = fileName;
  a.rel = "noopener";
  document.body.appendChild(a);
  a.click();
  a.remove();
  window.setTimeout(() => URL.revokeObjectURL(url), 60_000);
}

/**
 * Open an authenticated Blob in a new tab. Call `openPendingTab()` synchronously in the click handler
 * (popup blockers), then pass the window here once the Blob has loaded. Falls back to a download.
 */
export function openPendingTab(): Window | null {
  return typeof window !== "undefined" ? window.open("", "_blank") : null;
}

export function showBlobInTab(win: Window | null, blob: Blob, fallbackName: string) {
  if (!win) {
    saveBlob(blob, fallbackName);
    return;
  }
  const url = URL.createObjectURL(blob);
  win.location.href = url;
  window.setTimeout(() => URL.revokeObjectURL(url), 5 * 60_000);
}

/** Safe file-name fragment. */
export function slug(s: string): string {
  return s
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 40);
}
