import { randomUUID } from "crypto";
import type { ChannelOutboundAdapter } from "openclaw/plugin-sdk/feishu";
import { resolveAwadaAccount } from "./accounts.js";
import { getAwadaRuntime } from "./runtime.js";
import { decodeAwadaTo, sendTextToAwada } from "./send.js";

export const awadaOutbound: ChannelOutboundAdapter = {
  deliveryMode: "direct",
  chunker: (text, limit) => getAwadaRuntime().channel.text.chunkMarkdownText(text, limit),
  chunkerMode: "markdown",
  textChunkLimit: 2000,
  sendText: async ({ cfg, to, text, accountId }) => {
    const target = decodeAwadaTo(to);
    if (!target) {
      throw new Error(`[awada] Cannot decode target: ${to}`);
    }
    const account = resolveAwadaAccount({ cfg, accountId });
    if (!account.redisUrl) {
      throw new Error("[awada] redisUrl not configured");
    }
    const streamId = await sendTextToAwada({
      redisUrl: account.redisUrl,
      target,
      text,
      replyToEventId: randomUUID(),
      correlationId: randomUUID(),
      traceId: randomUUID(),
    });
    return { channel: "awada", messageId: streamId };
  },
  sendMedia: async ({ cfg, to, text, accountId }) => {
    // Awada doesn't support media uploads; send as plain text
    const target = decodeAwadaTo(to);
    if (!target) {
      throw new Error(`[awada] Cannot decode target: ${to}`);
    }
    const account = resolveAwadaAccount({ cfg, accountId });
    if (!account.redisUrl) {
      throw new Error("[awada] redisUrl not configured");
    }
    const body = text?.trim() ?? "[media]";
    const streamId = await sendTextToAwada({
      redisUrl: account.redisUrl,
      target,
      text: body,
      replyToEventId: randomUUID(),
      correlationId: randomUUID(),
      traceId: randomUUID(),
    });
    return { channel: "awada", messageId: streamId };
  },
};
