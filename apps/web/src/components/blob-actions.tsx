"use client";

import { useState, type ReactNode } from "react";
import { Download, ExternalLink } from "lucide-react";
import { openPendingTab, saveBlob, showBlobInTab } from "@/lib/download";
import { useToast } from "./toast";
import { Button, type ButtonProps } from "./ui";

/**
 * Fetches an authenticated file (PDF, CSV…) as a Blob and either saves it (`mode="download"`) or opens it
 * in a new tab (`mode="open"`). Never renders a raw API link: the endpoints need the bearer token.
 */
export function BlobButton({
  load,
  fileName,
  label,
  mode = "download",
  errorTitle = "Could not download the file",
  icon,
  variant = "secondary",
  size = "sm",
  ...rest
}: {
  load: () => Promise<Blob>;
  fileName: string;
  label: ReactNode;
  mode?: "download" | "open";
  errorTitle?: string;
  icon?: ReactNode;
} & Omit<ButtonProps, "onClick" | "children">) {
  const toast = useToast();
  const [loading, setLoading] = useState(false);

  const run = async () => {
    const win = mode === "open" ? openPendingTab() : null;
    setLoading(true);
    try {
      const blob = await load();
      if (mode === "open") showBlobInTab(win, blob, fileName);
      else saveBlob(blob, fileName);
    } catch (e) {
      win?.close();
      toast.apiError(e, errorTitle);
    } finally {
      setLoading(false);
    }
  };

  return (
    <Button
      variant={variant}
      size={size}
      loading={loading}
      onClick={run}
      icon={icon ?? (mode === "open" ? <ExternalLink className="size-4" aria-hidden /> : <Download className="size-4" aria-hidden />)}
      {...rest}
    >
      {label}
    </Button>
  );
}
