import { randomUUID } from "crypto";
import type { ChannelOutboundAdapter } from "openclaw/plugin-sdk/feishu";
import { resolveAwadaAccount } from "./accounts.js";
import { getAwadaRuntime } from "./runtime.js";
import { decodeAwadaTo, sendTextToAwada } from "./send.js";
import type { AwadaConfig } from "./types.js";

import { isNoReplyText } from "./silent-reply.js";

/**
 * Split text by perMsgMaxLen if configured, then send each chunk.
 * Returns the stream ID of the last sent chunk (for delivery tracking).
 */
async function sendChunked(params: {
  cfg: Parameters<ChannelOutboundAdapter["sendText"]>[0]["cfg"];
  redisUrl: string;
  target: ReturnType<typeof decodeAwadaTo>;
  text: string;
}): Promise<string> {
  const { cfg, redisUrl, target } = params;
  const awadaCfg = cfg.channels?.awada as AwadaConfig | undefined;
  const perMsgMaxLen = awadaCfg?.perMsgMaxLen;
  const chunks =
    perMsgMaxLen && params.text.length > perMsgMaxLen
      ? getAwadaRuntime().channel.text.chunkMarkdownText(params.text, perMsgMaxLen)
      : [params.text];

  let lastId = "";
  for (const chunk of chunks) {
    lastId = await sendTextToAwada({
      redisUrl,
      target: target!,
      text: chunk,
      replyToEventId: randomUUID(),
      correlationId: randomUUID(),
      traceId: randomUUID(),
    });
  }
  return lastId;
}

export const awadaOutbound: ChannelOutboundAdapter = {
  deliveryMode: "direct",
  chunker: (text, limit) => getAwadaRuntime().channel.text.chunkMarkdownText(text, limit),
  chunkerMode: "markdown",
  textChunkLimit: 2000,
  sendText: async ({ cfg, to, text, accountId }) => {
    if (isNoReplyText(text)) {
      return { channel: "awada", messageId: "no_reply_suppressed" };
    }
    const target = decodeAwadaTo(to);
    if (!target) {
      throw new Error(`[awada] Cannot decode target: ${to}`);
    }
    const account = resolveAwadaAccount({ cfg, accountId });
    if (!account.redisUrl) {
      throw new Error("[awada] redisUrl not configured");
    }
    const streamId = await sendChunked({
      cfg,
      redisUrl: account.redisUrl,
      target,
      text,
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
    const streamId = await sendChunked({
      cfg,
      redisUrl: account.redisUrl,
      target,
      text: body,
    });
    return { channel: "awada", messageId: streamId };
  },
};
