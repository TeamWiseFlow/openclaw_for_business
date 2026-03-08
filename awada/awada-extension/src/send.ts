import { randomUUID } from "crypto";
import { getPublisherClient } from "./redis-client.js";
import type { OutboundEvent, OutboundTarget } from "./redis-types.js";

const OUTBOUND_STREAM_PREFIX = "awada:events:outbound:";

export function encodeAwadaTo(target: OutboundTarget): string {
  return `awada:${Buffer.from(JSON.stringify(target)).toString("base64")}`;
}

export function decodeAwadaTo(to: string): OutboundTarget | null {
  if (!to.startsWith("awada:")) return null;
  try {
    return JSON.parse(Buffer.from(to.slice(6), "base64").toString("utf8")) as OutboundTarget;
  } catch {
    return null;
  }
}

export function buildOutboundTarget(meta: {
  lane: string;
  tenant_id: string;
  channel_id: string;
  user_id_external: string;
  platform: string;
  conversation_id?: string;
}): OutboundTarget {
  const target: OutboundTarget = {
    platform: meta.platform,
    tenant_id: meta.tenant_id,
    lane: meta.lane,
    user_id_external: meta.user_id_external,
    channel_id: meta.channel_id,
  };
  if (meta.conversation_id) {
    target.conversation_id = meta.conversation_id;
  }
  return target;
}

export async function publishOutboundEvent(
  redisUrl: string,
  event: OutboundEvent,
): Promise<string> {
  const client = getPublisherClient(redisUrl);
  const streamKey = `${OUTBOUND_STREAM_PREFIX}${event.target.lane}`;
  const messageId = await client.xadd(streamKey, "*", "data", JSON.stringify(event));
  if (!messageId) {
    throw new Error(`[awada] Failed to publish to ${streamKey}`);
  }
  return messageId;
}

export async function sendTextToAwada(params: {
  redisUrl: string;
  target: OutboundTarget;
  text: string;
  replyToEventId: string;
  correlationId: string;
  traceId: string;
}): Promise<string> {
  const { redisUrl, target, text, replyToEventId, correlationId, traceId } = params;
  const event: OutboundEvent = {
    schema_version: 1,
    event_id: randomUUID(),
    reply_to_event_id: replyToEventId || randomUUID(),
    type: "REPLY_MESSAGE",
    timestamp: Math.floor(Date.now() / 1000),
    correlation_id: correlationId || randomUUID(),
    trace_id: traceId || randomUUID(),
    target,
    payload: [{ type: "text", text }],
  };
  return publishOutboundEvent(redisUrl, event);
}
