import type { ClawdbotConfig, RuntimeEnv } from "openclaw/plugin-sdk/feishu";
import { getAwadaRuntime } from "./runtime.js";
import type { OutboundTarget } from "./redis-types.js";
import { sendTextToAwada } from "./send.js";

export type CreateAwadaReplyDispatcherParams = {
  cfg: ClawdbotConfig;
  agentId: string;
  runtime: RuntimeEnv;
  redisUrl: string;
  target: OutboundTarget;
  inboundEventId: string;
  correlationId: string;
  traceId: string;
  accountId?: string;
};

export function createAwadaReplyDispatcher(params: CreateAwadaReplyDispatcherParams) {
  const {
    cfg,
    runtime,
    redisUrl,
    target,
    inboundEventId,
    correlationId,
    traceId,
    accountId,
  } = params;
  const log = runtime?.log ?? console.log;
  const error = runtime?.error ?? console.error;
  const core = getAwadaRuntime();

  const pendingSends: Promise<void>[] = [];
  let idleResolve: (() => void) | null = null;
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  const _idlePromise = new Promise<void>((resolve) => {
    idleResolve = resolve;
  });

  const textChunkLimit = core.channel.text.resolveTextChunkLimit(cfg, "awada", accountId, {
    fallbackLimit: 2000,
  });

  const queueSend = (text: string) => {
    const trimmed = text.trim();
    if (!trimmed) return;
    const p = sendTextToAwada({
      redisUrl,
      target,
      text: trimmed,
      replyToEventId: inboundEventId,
      correlationId,
      traceId,
    })
      .then(() => {
        log(`awada[${accountId ?? "default"}]: reply sent to ${target.user_id_external}`);
      })
      .catch((err) => {
        error(`awada[${accountId ?? "default"}]: send failed: ${String(err)}`);
      });
    pendingSends.push(p);
  };

  const dispatcher = {
    sendFinalReply(payload: { text?: string }): boolean {
      const text = payload?.text ?? "";
      if (text.trim()) queueSend(text);
      return true;
    },
    sendBlockReply(_payload: { text?: string }): boolean {
      // Awada doesn't support streaming/progressive blocks — skip partial blocks
      return false;
    },
    sendToolResult(_payload: unknown): boolean {
      return false;
    },
    async waitForIdle(): Promise<void> {
      await Promise.all(pendingSends);
    },
    getQueuedCounts() {
      return { tool: 0, block: 0, final: pendingSends.length };
    },
    markComplete() {
      idleResolve?.();
    },
  };

  const markDispatchIdle = () => {
    idleResolve?.();
  };

  return { dispatcher, markDispatchIdle, textChunkLimit };
}
