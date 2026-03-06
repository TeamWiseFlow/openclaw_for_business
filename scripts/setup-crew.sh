#!/bin/bash
# setup-crew.sh - 多 Agent 系统安装脚本
# 将 crew/ 中的 workspace 模板、共享协议、角色模板部署到 ~/.openclaw/
# 幂等设计：已存在的 workspace 不会覆盖（除非 --force）
set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CREW_DIR="$PROJECT_ROOT/crew"
OPENCLAW_HOME="$HOME/.openclaw"
CONFIG_PATH="$OPENCLAW_HOME/openclaw.json"
FORCE=false

source "$SCRIPT_DIR/lib/agent-skills.sh"

BUILTIN_OVERRIDES=""

usage() {
  echo "Usage: $0 [--force] [--builtin-skills <agent-id>:<skill1,skill2|all>]"
  echo ""
  echo "Options:"
  echo "  --force                               Overwrite existing workspace files"
  echo "  --builtin-skills <agent-id>:<skills> Override bundled skills for one agent"
  echo ""
  echo "Examples:"
  echo "  $0"
  echo "  $0 --force"
  echo "  $0 --builtin-skills hrbp:browser-guide"
  echo "  $0 --builtin-skills main:all --builtin-skills hrbp:browser-guide,summarize"
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --force)
      FORCE=true
      shift
      ;;
    --builtin-skills)
      [ -z "$2" ] && { echo "❌ --builtin-skills requires <agent-id>:<skills>"; usage; }
      case "$2" in
        *:*)
          BUILTIN_OVERRIDES="${BUILTIN_OVERRIDES}
$2"
          ;;
        *)
          echo "❌ Invalid format for --builtin-skills: $2"
          echo "   Expected: <agent-id>:<skill1,skill2|all>"
          exit 1
          ;;
      esac
      shift 2
      ;;
    *)
      echo "❌ Unknown option: $1"
      usage
      ;;
  esac
done

resolve_builtin_override_for_agent() {
  local agent_id="$1"
  local line=""
  local key=""
  local value=""

  while IFS= read -r line; do
    [ -n "$line" ] || continue
    key="${line%%:*}"
    value="${line#*:}"
    if [ "$key" = "$agent_id" ]; then
      printf '%s\n' "$value"
      return
    fi
  done <<< "$BUILTIN_OVERRIDES"
}

sync_agent_skill_filter() {
  local agent_id="$1"
  local agent_override=""
  agent_override="$(resolve_builtin_override_for_agent "$agent_id")"

  local workspace_dir=""
  workspace_dir="$(node -e "
    const fs = require('fs');
    const c = JSON.parse(fs.readFileSync('$CONFIG_PATH', 'utf8'));
    const agent = (c.agents?.list || []).find((entry) => entry.id === '$agent_id');
    const configured = typeof agent?.workspace === 'string' && agent.workspace.trim()
      ? agent.workspace.trim()
      : '~/.openclaw/workspace-$agent_id';
    console.log(configured.replace(/^~(?=\\/|$)/, process.env.HOME));
  " 2>/dev/null)"

  if [ -z "$workspace_dir" ] || [ ! -d "$workspace_dir" ]; then
    echo "  ⚠️  workspace for agent '$agent_id' not found, skip skill filter sync"
    return
  fi

  local builtin_file="$workspace_dir/BUILTIN_SKILLS"
  local skills_json=""
  skills_json="$(resolve_agent_skills_json \
    "$agent_id" \
    "$workspace_dir" \
    "$agent_override" \
    "$builtin_file" \
    "$PROJECT_ROOT")"

  AGENT_ID="$agent_id" AGENT_SKILLS_JSON="$skills_json" node -e "
    const fs = require('fs');
    const c = JSON.parse(fs.readFileSync('$CONFIG_PATH', 'utf8'));
    const list = c.agents?.list || [];
    const idx = list.findIndex((entry) => entry.id === process.env.AGENT_ID);
    if (idx >= 0) {
      list[idx] = {
        ...list[idx],
        skills: JSON.parse(process.env.AGENT_SKILLS_JSON || '[]'),
      };
      fs.writeFileSync('$CONFIG_PATH', JSON.stringify(c, null, 2) + '\\n');
    }
  "
}

if [ ! -d "$CREW_DIR" ]; then
  echo "❌ crew/ directory not found at $CREW_DIR"
  exit 1
fi

echo "📦 Setting up Agent System (crew)..."

# ─── 1. 安装内置 Agent workspace（main + hrbp） ─────────────────
for agent_dir in "$CREW_DIR"/workspaces/*/; do
  [ -d "$agent_dir" ] || continue
  agent_id="$(basename "$agent_dir")"
  dest="$OPENCLAW_HOME/workspace-$agent_id"

  if [ -d "$dest" ] && [ "$FORCE" != "true" ]; then
    echo "  ⚠️  workspace-$agent_id already exists, skipping (use --force to overwrite)"
    continue
  fi

  mkdir -p "$dest"
  cp "$agent_dir"*.md "$dest/"
  if [ -f "$agent_dir/BUILTIN_SKILLS" ]; then
    cp "$agent_dir/BUILTIN_SKILLS" "$dest/"
  fi
  # 复制 Agent 专属 skills（���有）
  if [ -d "$agent_dir/skills" ]; then
    cp -r "$agent_dir/skills" "$dest/"
  fi
  echo "  ✅ workspace-$agent_id installed"
done

# ─── 2. 复制共享协议到每个已安装的 workspace ─────────────────────
for agent_dir in "$CREW_DIR"/workspaces/*/; do
  [ -d "$agent_dir" ] || continue
  agent_id="$(basename "$agent_dir")"
  dest="$OPENCLAW_HOME/workspace-$agent_id"
  if [ -d "$dest" ] && [ -d "$CREW_DIR/shared" ]; then
    cp "$CREW_DIR/shared/"*.md "$dest/"
  fi
done
echo "  ✅ Shared protocols (RULES.md, TEMPLATES.md) copied"

# ─── 3. 安装角色模板 ────────────────────────────────────────────���─
if [ -d "$CREW_DIR/role-templates" ]; then
  ROLE_DEST="$OPENCLAW_HOME/hrbp-templates"
  mkdir -p "$ROLE_DEST"
  cp -r "$CREW_DIR/role-templates/"* "$ROLE_DEST/"
  echo "  ✅ Role templates installed to $ROLE_DEST"
fi

# ─── 4. 更新 openclaw.json（合并 main/hrbp + skills 白名单） ──────
if [ -f "$CONFIG_PATH" ]; then
  echo "  📝 Merging agent config into openclaw.json..."

  MAIN_OVERRIDE="$(resolve_builtin_override_for_agent "main")"
  HRBP_OVERRIDE="$(resolve_builtin_override_for_agent "hrbp")"

  MAIN_SKILLS_JSON="$(resolve_agent_skills_json \
    "main" \
    "$OPENCLAW_HOME/workspace-main" \
    "$MAIN_OVERRIDE" \
    "$OPENCLAW_HOME/workspace-main/BUILTIN_SKILLS" \
    "$PROJECT_ROOT")"
  HRBP_SKILLS_JSON="$(resolve_agent_skills_json \
    "hrbp" \
    "$OPENCLAW_HOME/workspace-hrbp" \
    "$HRBP_OVERRIDE" \
    "$OPENCLAW_HOME/workspace-hrbp/BUILTIN_SKILLS" \
    "$PROJECT_ROOT")"

  MAIN_SKILLS_JSON="$MAIN_SKILLS_JSON" HRBP_SKILLS_JSON="$HRBP_SKILLS_JSON" node -e "
    const fs = require('fs');
    const c = JSON.parse(fs.readFileSync('$CONFIG_PATH', 'utf8'));
    const mainSkills = JSON.parse(process.env.MAIN_SKILLS_JSON || '[]');
    const hrbpSkills = JSON.parse(process.env.HRBP_SKILLS_JSON || '[]');

    if (!c.agents) c.agents = {};
    if (!Array.isArray(c.agents.list)) c.agents.list = [];

    const upsertAgent = (id, buildNext) => {
      const idx = c.agents.list.findIndex((entry) => entry.id === id);
      const prev = idx >= 0 ? c.agents.list[idx] : {};
      const next = buildNext(prev);
      if (idx >= 0) c.agents.list[idx] = next;
      else c.agents.list.push(next);
    };

    upsertAgent('main', (prev) => {
      const allowAgents = Array.isArray(prev?.subagents?.allowAgents) ? prev.subagents.allowAgents : [];
      const mergedAllowAgents = Array.from(new Set([...allowAgents, 'main', 'hrbp']));
      return {
        ...prev,
        id: 'main',
        default: prev.default ?? true,
        name: prev.name || 'Main Agent',
        workspace: prev.workspace || '~/.openclaw/workspace-main',
        skills: mainSkills,
        subagents: {
          ...(prev.subagents || {}),
          allowAgents: mergedAllowAgents,
        },
      };
    });

    upsertAgent('hrbp', (prev) => ({
      ...prev,
      id: 'hrbp',
      name: prev.name || 'HRBP',
      workspace: prev.workspace || '~/.openclaw/workspace-hrbp',
      skills: hrbpSkills,
    }));

    // 配置飞书多账户 -> Agent 绑定（模式 B：渠道直连）
    if (!Array.isArray(c.bindings) || c.bindings.length === 0) {
      c.bindings = [
        { agentId: 'main', comment: 'main-bot -> Main Agent', match: { channel: 'feishu', accountId: 'main-bot' } },
        { agentId: 'hrbp', comment: 'hrbp-bot -> HRBP Agent', match: { channel: 'feishu', accountId: 'hrbp-bot' } }
      ];
    }

    fs.writeFileSync('$CONFIG_PATH', JSON.stringify(c, null, 2) + '\\n');
  "
  AGENT_IDS="$(node -e "
    const fs = require('fs');
    const c = JSON.parse(fs.readFileSync('$CONFIG_PATH', 'utf8'));
    console.log((c.agents?.list || []).map((entry) => entry.id).join('\\n'));
  " 2>/dev/null)"
  while IFS= read -r agent_id; do
    [ -n "$agent_id" ] || continue
    sync_agent_skill_filter "$agent_id"
  done <<< "$AGENT_IDS"
  echo "  ✅ Agent skills filters synchronized"
  echo "  ✅ openclaw.json updated"
else
  echo "  ⚠️  openclaw.json not found at $CONFIG_PATH"
  echo "     Will be created on first start (dev.sh / reinstall-daemon.sh)"
fi

# ─── 5. 完成 ──────────────────────────────────────────────────────
echo ""
echo "✅ Agent System installed!"
echo ""
echo "Installed locations:"
echo "  Workspaces:  $OPENCLAW_HOME/workspace-main/, workspace-hrbp/"
echo "  Templates:   $OPENCLAW_HOME/hrbp-templates/"
echo "  Config:      $CONFIG_PATH"
