"use client";

import { useState } from "react";
import { ExternalLink } from "lucide-react";
import { api } from "@/lib/api";
import { useToast } from "./toast";
import { Button } from "./ui";

/**
 * Opens GET /records/:id/file. The endpoint requires the bearer token, so the bytes are fetched
 * with auth as a Blob and shown through an object URL (never a raw link).
 */
export function OpenOriginalButton({ recordId, label = "Open original", fileName }: { recordId: string; label?: string; fileName?: string }) {
  const toast = useToast();
  const [loading, setLoading] = useState(false);

  const open = async () => {
    // Open the tab synchronously (inside the click) so popup blockers allow it.
    const win = window.open("", "_blank");
    setLoading(true);
    try {
      const blob = await api.records.file(recordId);
      const url = URL.createObjectURL(blob);
      if (win) {
        win.location.href = url;
      } else {
        const a = document.createElement("a");
        a.href = url;
        a.download = fileName ?? "record";
        a.rel = "noopener";
        document.body.appendChild(a);
        a.click();
        a.remove();
      }
      window.setTimeout(() => URL.revokeObjectURL(url), 5 * 60_000);
    } catch (e) {
      win?.close();
      toast.apiError(e, "Could not open the original file");
    } finally {
      setLoading(false);
    }
  };

  return (
    <Button
      variant="secondary"
      size="sm"
      onClick={open}
      loading={loading}
      icon={<ExternalLink className="size-4" aria-hidden />}
      aria-label={`${label}${fileName ? `: ${fileName}` : ""} (opens in a new tab)`}
    >
      {label}
    </Button>
  );
}
