import type {
  ChannelOnboardingAdapter,
  ChannelOnboardingDmPolicy,
  ClawdbotConfig,
  DmPolicy,
  WizardPrompter,
} from "openclaw/plugin-sdk/feishu";
import { DEFAULT_ACCOUNT_ID } from "openclaw/plugin-sdk/feishu";
import { probeAwada } from "./probe.js";
import type { AwadaConfig } from "./types.js";

const channel = "awada" as const;

function getAwadaCfg(cfg: ClawdbotConfig): AwadaConfig | undefined {
  return cfg.channels?.awada as AwadaConfig | undefined;
}

function setAwadaDmPolicy(cfg: ClawdbotConfig, dmPolicy: DmPolicy): ClawdbotConfig {
  return {
    ...cfg,
    channels: {
      ...cfg.channels,
      awada: {
        ...getAwadaCfg(cfg),
        dmPolicy,
      },
    },
  };
}

function setAwadaAllowFrom(cfg: ClawdbotConfig, allowFrom: string[]): ClawdbotConfig {
  return {
    ...cfg,
    channels: {
      ...cfg.channels,
      awada: {
        ...getAwadaCfg(cfg),
        allowFrom,
      },
    },
  };
}

async function promptAwadaAllowFrom(params: {
  cfg: ClawdbotConfig;
  prompter: WizardPrompter;
}): Promise<ClawdbotConfig> {
  const existing = getAwadaCfg(params.cfg)?.allowFrom ?? [];
  const entry = await params.prompter.text({
    message: "Awada allowFrom (user_id_external values, comma-separated)",
    placeholder: "user_123, user_456",
    initialValue: existing.join(", "),
    validate: (value) => (String(value ?? "").trim() ? undefined : "Required"),
  });
  const parts = String(entry)
    .split(/[\n,;]+/)
    .map((s) => s.trim())
    .filter(Boolean);
  const unique = [...new Set([...existing, ...parts])];
  return setAwadaAllowFrom(params.cfg, unique);
}

const dmPolicy: ChannelOnboardingDmPolicy = {
  label: "Awada",
  channel,
  policyKey: "channels.awada.dmPolicy",
  allowFromKey: "channels.awada.allowFrom",
  getCurrent: (cfg) => (getAwadaCfg(cfg)?.dmPolicy ?? "open") as DmPolicy,
  setPolicy: (cfg, policy) => setAwadaDmPolicy(cfg, policy),
  promptAllowFrom: promptAwadaAllowFrom,
};

export const awadaOnboardingAdapter: ChannelOnboardingAdapter = {
  channel,
  getStatus: async ({ cfg }) => {
    const awadaCfg = getAwadaCfg(cfg);
    const redisUrl = awadaCfg?.redisUrl?.trim();
    const configured = Boolean(redisUrl);

    let probeResult = null;
    if (configured && redisUrl) {
      try {
        probeResult = await probeAwada({ redisUrl });
      } catch {
        // ignore
      }
    }

    const statusLines: string[] = [];
    if (!configured) {
      statusLines.push("Awada: needs Redis URL");
    } else if (probeResult?.ok) {
      statusLines.push("Awada: connected to Redis");
    } else {
      statusLines.push("Awada: configured (connection not verified)");
    }

    return {
      channel,
      configured,
      statusLines,
      selectionHint: configured ? "configured" : "needs Redis URL",
      quickstartScore: configured ? 2 : 0,
    };
  },

  configure: async ({ cfg, prompter }) => {
    const awadaCfg = getAwadaCfg(cfg);
    const currentUrl = awadaCfg?.redisUrl?.trim() ?? "";

    await prompter.note(
      [
        "Configure awada channel to receive WeChat messages via awada-server Redis bridge.",
        "You need:",
        "  1. A running awada-server that publishes events to Redis Streams",
        "  2. Redis URL (e.g. redis://localhost:6379 or redis://:pass@host:6379)",
        "  3. Lane names to subscribe to (default: user)",
      ].join("\n"),
      "Awada setup",
    );

    const redisUrl = String(
      await prompter.text({
        message: "Redis URL",
        placeholder: "redis://localhost:6379",
        initialValue: currentUrl,
        validate: (value) => (String(value ?? "").trim() ? undefined : "Required"),
      }),
    ).trim();

    let next: ClawdbotConfig = {
      ...cfg,
      channels: {
        ...cfg.channels,
        awada: {
          ...awadaCfg,
          enabled: true,
          redisUrl,
        },
      },
    };

    // Test connection
    try {
      const probe = await probeAwada({ redisUrl });
      if (probe.ok) {
        await prompter.note("Redis connection successful!", "Awada connection test");
      } else {
        await prompter.note(
          `Connection failed: ${probe.error ?? "unknown error"}`,
          "Awada connection test",
        );
      }
    } catch (err) {
      await prompter.note(`Connection test failed: ${String(err)}`, "Awada connection test");
    }

    // Lanes configuration
    const currentLanes = awadaCfg?.lanes?.join(", ") ?? "user";
    const lanesInput = String(
      await prompter.text({
        message: "Lanes to subscribe to (comma-separated)",
        placeholder: "user",
        initialValue: currentLanes,
      }),
    ).trim();
    if (lanesInput) {
      const lanes = lanesInput
        .split(/[\n,;]+/)
        .map((s) => s.trim())
        .filter(Boolean);
      next = {
        ...next,
        channels: {
          ...next.channels,
          awada: {
            ...(next.channels?.awada as AwadaConfig),
            lanes,
          },
        },
      };
    }

    return { cfg: next, accountId: DEFAULT_ACCOUNT_ID };
  },

  dmPolicy,

  disable: (cfg) => ({
    ...cfg,
    channels: {
      ...cfg.channels,
      awada: { ...getAwadaCfg(cfg), enabled: false },
    },
  }),
};
