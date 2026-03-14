import type { ChannelMeta, ChannelPlugin, ClawdbotConfig } from "openclaw/plugin-sdk/feishu";
import {
  buildProbeChannelStatusSummary,
  buildRuntimeAccountStatusSnapshot,
  createDefaultChannelRuntimeState,
  DEFAULT_ACCOUNT_ID,
} from "openclaw/plugin-sdk/feishu";
import {
  resolveAwadaAccount,
  listAwadaAccountIds,
  resolveDefaultAwadaAccountId,
} from "./accounts.js";
import { awadaOnboardingAdapter } from "./onboarding.js";
import { awadaOutbound } from "./outbound.js";
import { probeAwada } from "./probe.js";
import type { ResolvedAwadaAccount, AwadaConfig } from "./types.js";

const meta: ChannelMeta = {
  id: "awada",
  label: "Awada",
  selectionLabel: "Awada (WeChat via Redis)",
  docsPath: "/channels/awada",
  docsLabel: "awada",
  blurb: "WeChat (enterprise/personal) via awada-server Redis bridge.",
  aliases: [],
  order: 80,
};

export const awadaPlugin: ChannelPlugin<ResolvedAwadaAccount> = {
  id: "awada",
  meta,
  capabilities: {
    chatTypes: ["direct"],
    polls: false,
    threads: false,
    media: false,
    reactions: false,
    edit: false,
    reply: false,
  },
  agentPrompt: {
    messageToolHints: () => [
      "- Awada targeting: replies are routed back to the originating WeChat user automatically.",
    ],
  },
  reload: { configPrefixes: ["channels.awada"] },
  configSchema: {
    schema: {
      type: "object",
      additionalProperties: false,
      properties: {
        enabled: { type: "boolean" },
        redisUrl: { type: "string" },
        lane: { type: "string" },
        platform: { type: "string" },
        consumerGroup: { type: "string" },
        consumerName: { type: "string" },
        dmPolicy: { type: "string", enum: ["open", "pairing", "allowlist"] },
        allowFrom: { type: "array", items: { type: "string" } },
        maxRetries: { type: "integer", minimum: 1 },
        blockTimeMs: { type: "integer", minimum: 1 },
        batchSize: { type: "integer", minimum: 1 },
        perMsgMaxLen: { type: "integer", minimum: 1 },
      },
    },
  },
  config: {
    listAccountIds: (cfg) => listAwadaAccountIds(cfg),
    resolveAccount: (cfg, accountId) => resolveAwadaAccount({ cfg, accountId }),
    defaultAccountId: (cfg) => resolveDefaultAwadaAccountId(cfg),
    setAccountEnabled: ({ cfg, enabled }) => ({
      ...cfg,
      channels: {
        ...cfg.channels,
        awada: {
          ...(cfg.channels?.awada as AwadaConfig | undefined),
          enabled,
        },
      },
    }),
    deleteAccount: ({ cfg }) => {
      const next = { ...cfg } as ClawdbotConfig;
      const nextChannels = { ...cfg.channels };
      delete (nextChannels as Record<string, unknown>).awada;
      if (Object.keys(nextChannels).length > 0) {
        next.channels = nextChannels;
      } else {
        delete next.channels;
      }
      return next;
    },
    isConfigured: (account) => account.configured,
    describeAccount: (account) => ({
      accountId: account.accountId,
      enabled: account.enabled,
      configured: account.configured,
      redisUrl: account.redisUrl,
    }),
    resolveAllowFrom: ({ cfg, accountId }) => {
      const account = resolveAwadaAccount({ cfg, accountId });
      return (account.config?.allowFrom ?? []).map((entry) => String(entry));
    },
    formatAllowFrom: ({ allowFrom }) =>
      allowFrom
        .map((entry) => String(entry).trim())
        .filter(Boolean),
  },
  setup: {
    resolveAccountId: () => DEFAULT_ACCOUNT_ID,
    applyAccountConfig: ({ cfg }) => ({
      ...cfg,
      channels: {
        ...cfg.channels,
        awada: {
          ...(cfg.channels?.awada as AwadaConfig | undefined),
          enabled: true,
        },
      },
    }),
  },
  onboarding: awadaOnboardingAdapter,
  outbound: awadaOutbound,
  status: {
    defaultRuntime: createDefaultChannelRuntimeState(DEFAULT_ACCOUNT_ID, { port: null }),
    buildChannelSummary: ({ snapshot }) =>
      buildProbeChannelStatusSummary(snapshot, { port: null }),
    probeAccount: async ({ account }) =>
      probeAwada({ redisUrl: account.redisUrl, accountId: account.accountId }),
    buildAccountSnapshot: ({ account, runtime, probe }) => ({
      accountId: account.accountId,
      enabled: account.enabled,
      configured: account.configured,
      redisUrl: account.redisUrl,
      ...buildRuntimeAccountStatusSnapshot({ runtime, probe }),
      port: null,
    }),
  },
  gateway: {
    startAccount: async (ctx) => {
      const { monitorAwadaProvider } = await import("./monitor.js");
      ctx.log?.info(`starting awada[${ctx.accountId}]`);
      return monitorAwadaProvider({
        config: ctx.cfg,
        runtime: ctx.runtime,
        abortSignal: ctx.abortSignal,
        accountId: ctx.accountId,
      });
    },
  },
};
