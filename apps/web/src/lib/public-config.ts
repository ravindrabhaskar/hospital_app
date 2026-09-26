"use client";

import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";
import type { PublicConfig } from "@/lib/api/types";

/** GET /config/public (§21, no auth). Cached for 5 minutes; callers must tolerate it being unavailable. */
export function usePublicConfig() {
  return useQuery<PublicConfig>({
    queryKey: ["config", "public"],
    queryFn: () => api.config.public(),
    staleTime: 5 * 60_000,
    retry: 1,
  });
}
