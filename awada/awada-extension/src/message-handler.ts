import type { ClawdbotConfig, RuntimeEnv } from "openclaw/plugin-sdk/feishu";
import { DEFAULT_ACCOUNT_ID } from "openclaw/plugin-sdk/feishu";
import { resolveAwadaAccount } from "./accounts.js";
import { createAwadaReplyDispatcher } from "./reply-dispatcher.js";
import { getAwadaRuntime } from "./runtime.js";
import type { InboundEvent } from "./redis-types.js";
import { buildOutboundTarget, encodeAwadaTo } from "./send.js";

/**
 * Extract text from a payload array. Returns the concatenated text of all text objects.
 */
function extractTextFromPayload(payload: InboundEvent["payload"]): string {
  return payload
    .filter((item) => item.type === "text")
    .map((item) => (item as { type: "text"; text: string }).text)
    .join("\n")
    .trim();
}

/**
 * Handle a single inbound awada event, dispatching to the OpenClaw agent.
 */
export async function handleAwadaMessage(params: {
  cfg: ClawdbotConfig;
  event: InboundEvent;
  runtime?: RuntimeEnv;
  accountId?: string;
}): Promise<void> {
  const { cfg, event, runtime, accountId = DEFAULT_ACCOUNT_ID } = params;
  const log = runtime?.log ?? console.log;
  const error = runtime?.error ?? console.error;

  const account = resolveAwadaAccount({ cfg, accountId });
  if (!account.enabled || !account.configured) {
    log(`awada[${accountId}]: account not enabled or configured, skipping`);
    return;
  }

  const { meta, payload, event_id, correlation_id, trace_id } = event;
  const text = extractTextFromPayload(payload);

  if (!text) {
    log(`awada[${accountId}]: no text in payload for event ${event_id}, skipping`);
    return;
  }

  log(
    `awada[${accountId}]: received message from ${meta.user_id_external} in lane ${meta.lane}: ${text.slice(0, 80)}`,
  );

  const core = getAwadaRuntime();

  // Build the reply target (used for sending back via outbound stream)
  const target = buildOutboundTarget({
    lane: meta.lane,
    tenant_id: meta.tenant_id,
    channel_id: meta.channel_id,
    user_id_external: meta.user_id_external,
    platform: meta.platform,
    conversation_id: meta.conversation_id,
  });
  const awadaTo = encodeAwadaTo(target);
  const awadaFrom = `awada:${meta.user_id_external}`;

  // Resolve agent route
  const route = core.channel.routing.resolveAgentRoute({
    cfg,
    channel: "awada",
    accountId,
    peer: { kind: "direct", id: meta.user_id_external },
  });

  // Build agent envelope
  const envelopeOptions = core.channel.reply.resolveEnvelopeFormatOptions(cfg);
  const messageBody = `${meta.user_id_external}: ${text}`;
  const body = core.channel.reply.formatAgentEnvelope({
    channel: "Awada",
    from: awadaFrom,
    timestamp: new Date(event.timestamp * 1000),
    envelope: envelopeOptions,
    body: messageBody,
  });

  const ctxPayload = core.channel.reply.finalizeInboundContext({
    Body: body,
    BodyForAgent: messageBody,
    RawBody: text,
    CommandBody: text,
    From: awadaFrom,
    To: awadaTo,
    SessionKey: route.sessionKey,
    AccountId: route.accountId,
    ChatType: "direct",
    SenderId: meta.user_id_external,
    SenderName: meta.user_id_external,
    Provider: "awada" as const,
    Surface: "awada" as const,
    MessageSid: event_id,
    Timestamp: event.timestamp * 1000,
    OriginatingChannel: "awada" as const,
    OriginatingTo: awadaTo,
  });

  const { dispatcher, markDispatchIdle } = createAwadaReplyDispatcher({
    cfg,
    agentId: route.agentId,
    runtime: runtime as RuntimeEnv,
    redisUrl: account.redisUrl!,
    target,
    inboundEventId: event_id,
    correlationId: correlation_id,
    traceId: trace_id,
    accountId,
  });

  try {
    log(`awada[${accountId}]: dispatching to agent (session=${route.sessionKey})`);
    await core.channel.reply.withReplyDispatcher({
      dispatcher,
      onSettled: () => markDispatchIdle(),
      run: () =>
        core.channel.reply.dispatchReplyFromConfig({
          ctx: ctxPayload,
          cfg,
          dispatcher,
        }),
    });
  } catch (err) {
    error(`awada[${accountId}]: dispatch failed: ${String(err)}`);
  }
}
