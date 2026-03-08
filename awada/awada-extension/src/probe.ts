import Redis from "ioredis";
import type { AwadaProbeResult } from "./types.js";

const PROBE_TIMEOUT_MS = 5000;

/**
 * Probe Redis connectivity for an awada account.
 * Returns ok=true if PING succeeds within timeout.
 */
export async function probeAwada(params: {
  redisUrl?: string;
  accountId?: string;
}): Promise<AwadaProbeResult> {
  const { redisUrl, accountId } = params;

  if (!redisUrl) {
    return { ok: false, error: "missing redisUrl" };
  }

  let client: Redis | null = null;
  const timeoutHandle = setTimeout(() => {
    client?.disconnect();
  }, PROBE_TIMEOUT_MS);

  try {
    client = new Redis(redisUrl, {
      maxRetriesPerRequest: 1,
      enableOfflineQueue: false,
      connectTimeout: PROBE_TIMEOUT_MS,
      lazyConnect: true,
    });

    await client.connect();
    const pong = await client.ping();

    if (pong !== "PONG") {
      return {
        ok: false,
        redisUrl,
        error: `unexpected PING response: ${pong}`,
      };
    }

    return { ok: true, redisUrl };
  } catch (err) {
    return {
      ok: false,
      redisUrl,
      error: err instanceof Error ? err.message : String(err),
    };
  } finally {
    clearTimeout(timeoutHandle);
    try {
      await client?.quit();
    } catch {
      // ignore
    }
  }
}
