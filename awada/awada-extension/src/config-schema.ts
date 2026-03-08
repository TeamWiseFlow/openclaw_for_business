import { z } from "zod";
export { z };

export const AwadaConfigSchema = z
  .object({
    enabled: z.boolean().optional(),
    /** Redis connection URL, e.g. "redis://localhost:6379" or "redis://:pass@host:port/db" */
    redisUrl: z.string().optional(),
    /** Lanes to subscribe to. Each lane maps to awada:events:inbound:<lane>. Default: ["user"] */
    lanes: z.array(z.string()).optional(),
    /** Redis consumer group name. Default: "openclaw" */
    consumerGroup: z.string().optional(),
    /** Redis consumer name (unique per process). Default: "openclaw_bot" */
    consumerName: z.string().optional(),
    /** DM policy: open (anyone), pairing (requires approval), or allowlist */
    dmPolicy: z.enum(["open", "pairing", "allowlist"]).optional(),
    /** Allowed user_id_external values for allowlist/pairing */
    allowFrom: z.array(z.string()).optional(),
    /** Max retries before moving message to DLQ. Default: 5 */
    maxRetries: z.number().int().positive().optional(),
    /** XREADGROUP BLOCK timeout in ms. Default: 5000 */
    blockTimeMs: z.number().int().positive().optional(),
    /** Batch size for XREADGROUP. Default: 10 */
    batchSize: z.number().int().positive().optional(),
  })
  .strict();

/** Per-account override (currently unused — awada uses a single default account) */
export const AwadaAccountConfigSchema = z
  .object({
    enabled: z.boolean().optional(),
    name: z.string().optional(),
  })
  .strict();
