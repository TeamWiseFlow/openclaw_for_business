import type { OpenClawPluginApi } from "openclaw/plugin-sdk/core";
import { emptyPluginConfigSchema } from "openclaw/plugin-sdk/core";
import { readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { join } from "node:path";

type CustomerRow = {
  peer: string;
  business_status: string;
  purpose: string;
  prompt_source: string;
  club_in: string;
  created_at: string;
  updated_at: string;
};

function extractSuffixFromSessionKey(sessionKey?: string): string | null {
  if (!sessionKey) return null;
  const preferred = sessionKey.match(/^agent:[^:]+:awada:direct:(.+)$/);
  if (preferred?.[1]) return preferred[1];
  const tolerant = sessionKey.match(/^agent:.*:awada:direct:(.+)$/);
  if (tolerant?.[1]) return tolerant[1];
  return null;
}

function resolvePeerFromSessionKey(sessionKey?: string): string | null {
  return extractSuffixFromSessionKey(sessionKey);
}

function resolvePeerForCommand(ctx: {
  channel: string;
  sessionKey?: string;
}): string | null {
  if (ctx.channel !== "awada") return null;
  return resolvePeerFromSessionKey(ctx.sessionKey);
}

function sqliteExec(dbFile: string, args: string[], options?: { input?: string }) {
  const res = spawnSync("sqlite3", [dbFile, ...args], {
    encoding: "utf8",
    input: options?.input,
  });
  if (res.status !== 0) {
    throw new Error(res.stderr || res.stdout || "sqlite3 command failed");
  }
  return (res.stdout || "").trim();
}

function ensureDatabaseReady(params: {
  dbFile: string;
  schemaFile: string;
}) {
  const { dbFile, schemaFile } = params;

  const tableName = sqliteExec(dbFile, [
    "SELECT name FROM sqlite_master WHERE type='table' AND name='cs_record';",
  ]);

  if (tableName === "cs_record") return;

  const schemaSql = readFileSync(schemaFile, "utf8");
  sqliteExec(dbFile, [], { input: schemaSql });
}

function sqlQuote(input: string): string {
  return `'${input.replace(/'/g, "''")}'`;
}

function ensurePeerRow(dbFile: string, peer: string) {
  sqliteExec(dbFile, [
    `INSERT INTO cs_record (peer, business_status, purpose, prompt_source) VALUES (${sqlQuote(peer)}, 'free', '', '') ON CONFLICT(peer) DO UPDATE SET updated_at = strftime('%Y-%m-%d %H:%M:%S', 'now', 'localtime');`,
  ]);
}

function updateForPaymentSuccess(dbFile: string, peer: string) {
  sqliteExec(dbFile, [
    `UPDATE cs_record SET business_status='subs', club_in=strftime('%Y-%m-%d', 'now', 'localtime') WHERE peer=${sqlQuote(peer)};`,
  ]);
}

function updateForClubJoin(dbFile: string, peer: string) {
  sqliteExec(dbFile, [
    `UPDATE cs_record SET business_status='club', club_in=strftime('%Y-%m-%d', 'now', 'localtime') WHERE peer=${sqlQuote(peer)};`,
  ]);
}

function selectCustomerRow(dbFile: string, peer: string): CustomerRow | null {
  const out = sqliteExec(dbFile, [
    "-separator",
    "\t",
    `SELECT peer, business_status, purpose, prompt_source, club_in, created_at, updated_at FROM cs_record WHERE peer=${sqlQuote(peer)} LIMIT 1;`,
  ]);

  if (!out) return null;
  const [p, business_status, purpose, prompt_source, club_in, created_at, updated_at] =
    out.split("\t");

  return {
    peer: p ?? peer,
    business_status: business_status ?? "free",
    purpose: purpose ?? "",
    prompt_source: prompt_source ?? "",
    club_in: club_in ?? "",
    created_at: created_at ?? "",
    updated_at: updated_at ?? "",
  };
}

const STATIC_RULES = [
  "CustomerDB 规则（每轮适用）：",
  "- [CustomerDB].peer 是当前客户在数据库中的主键，用于所有 SQL 查询和写库操作。",
  "- Sender 块中的 id（即 user_id_external）是 awada 原始用户标识，用于需要与 awada 交互的技能（如 exp_invite）。",
  "- 仅在信息更明确时更新 business_status/purpose/prompt_source。",
  "- 字段为空时不要臆测。",
].join("\n");

function buildDynamicContext(row: CustomerRow): string {
  return [
    "[CustomerDB]",
    `peer: ${row.peer}`,
    `business_status: ${row.business_status}`,
    `club_in: ${row.club_in || ""}`,
    `purpose: ${row.purpose || ""}`,
    `prompt_source: ${row.prompt_source || ""}`,
    `updated_at: ${row.updated_at || ""}`,
    "[/CustomerDB]",
  ].join("\n");
}

const plugin = {
  id: "customerdb-hook",
  name: "Sales CS CustomerDB Hook",
  description: "Inject customer DB context and handle sales commands without LLM.",
  configSchema: emptyPluginConfigSchema(),
  register(api: OpenClawPluginApi) {
    const cfg = (api.pluginConfig ?? {}) as { agentId?: string; workspaceDir?: string };
    const agentId = cfg.agentId || "sales-cs";
    const workspaceDir = cfg.workspaceDir || "/home/wukong/.openclaw/workspace-sales-cs";
    const dbFile = join(workspaceDir, "db", "customer.db");
    const schemaFile = join(workspaceDir, "db", "schema.sql");

    const preparePeer = (peer: string) => {
      ensureDatabaseReady({ dbFile, schemaFile });
      ensurePeerRow(dbFile, peer);
    };

    api.registerCommand({
      name: "payment_success",
      description: "Mark customer as subscription-success (silent)",
      acceptsArgs: false,
      requireAuth: false,
      handler: async (ctx) => {
        try {
          const peer = resolvePeerForCommand({
            channel: ctx.channel,
            sessionKey: ctx.sessionKey,
          });
          if (!peer) {
            api.logger.warn?.(
              `payment_success: peer unresolved from sessionKey (channel=${ctx.channel}, sessionKey=${ctx.sessionKey ?? ""})`,
            );
            return { text: "NO_REPLY" };
          }
          preparePeer(peer);
          updateForPaymentSuccess(dbFile, peer);
          return { text: "NO_REPLY" };
        } catch (err) {
          api.logger.warn?.(
            `payment_success command failed: ${err instanceof Error ? err.message : String(err)}`,
          );
          return { text: "NO_REPLY" };
        }
      },
    });

    api.registerCommand({
      name: "club_join",
      description: "Mark customer as club member and stamp join date (silent)",
      acceptsArgs: false,
      requireAuth: false,
      handler: async (ctx) => {
        try {
          const peer = resolvePeerForCommand({
            channel: ctx.channel,
            sessionKey: ctx.sessionKey,
          });
          if (!peer) {
            api.logger.warn?.(
              `club_join: peer unresolved from sessionKey (channel=${ctx.channel}, sessionKey=${ctx.sessionKey ?? ""})`,
            );
            return { text: "NO_REPLY" };
          }
          preparePeer(peer);
          updateForClubJoin(dbFile, peer);
          return { text: "NO_REPLY" };
        } catch (err) {
          api.logger.warn?.(
            `club_join command failed: ${err instanceof Error ? err.message : String(err)}`,
          );
          return { text: "NO_REPLY" };
        }
      },
    });

    api.on("before_prompt_build", (event, ctx) => {
      try {
        if (ctx.agentId !== agentId) return;
        const peer = resolvePeerFromSessionKey(ctx.sessionKey);
        if (!peer) return;

        preparePeer(peer);
        const row = selectCustomerRow(dbFile, peer);
        if (!row) return;

        return {
          prependSystemContext: STATIC_RULES,
          appendSystemContext: buildDynamicContext(row),
        };
      } catch (err) {
        api.logger.warn?.(
          `before_prompt_build customer-db injection failed: ${err instanceof Error ? err.message : String(err)}`,
        );
        return;
      }
    });
  },
};

export default plugin;
