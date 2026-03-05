#!/bin/bash
# add-agent.sh - 注册新 Agent 到 openclaw.json
# 用法: bash ./skills/hrbp-recruit/scripts/add-agent.sh <agent-id> [--bind <channel>:<accountId>] [--builtin-skills <skill1,skill2|all>]
set -e

OPENCLAW_HOME="$HOME/.openclaw"
CONFIG_PATH="$OPENCLAW_HOME/openclaw.json"

usage() {
  echo "Usage: $0 <agent-id> [--bind <channel>:<accountId>] [--builtin-skills <skill1,skill2|all>]"
  echo ""
  echo "Options:"
  echo "  --bind <channel>:<accountId>  Bind agent to a channel (Mode B direct routing)"
  echo "  --builtin-skills <skills>     Enable bundled skills for this agent (comma-separated)"
  echo ""
  echo "Examples:"
  echo "  $0 developer"
  echo "  $0 developer --builtin-skills browser-guide,summarize"
  echo "  $0 customer-service --bind wechat:wx_xxx"
  exit 1
}

split_skill_tokens() {
  local raw="$1"
  printf '%s\n' "$raw" \
    | sed 's/#.*$//' \
    | tr ',' '\n' \
    | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
    | awk 'NF'
}

list_workspace_skill_names() {
  local workspace_dir="$1"
  local workspace_skills_dir="$workspace_dir/skills"

  if [ ! -d "$workspace_skills_dir" ]; then
    return
  fi

  for skill_dir in "$workspace_skills_dir"/*/; do
    [ -d "$skill_dir" ] || continue
    if [ -f "${skill_dir}SKILL.md" ]; then
      basename "$skill_dir"
    fi
  done | sort
}

find_bundled_skills_dir() {
  if [ -n "$OPENCLAW_BUNDLED_SKILLS_DIR" ] && [ -d "$OPENCLAW_BUNDLED_SKILLS_DIR" ]; then
    printf '%s\n' "$OPENCLAW_BUNDLED_SKILLS_DIR"
    return
  fi

  if command -v openclaw >/dev/null 2>&1; then
    local openclaw_bin=""
    openclaw_bin="$(command -v openclaw)"
    local sibling_skills_dir
    sibling_skills_dir="$(cd "$(dirname "$openclaw_bin")" && pwd)/skills"
    if [ -d "$sibling_skills_dir" ]; then
      printf '%s\n' "$sibling_skills_dir"
      return
    fi
  fi

  local current_dir=""
  current_dir="$(cd "$(dirname "$0")" && pwd)"
  local i=0
  while [ "$i" -lt 10 ]; do
    if [ -d "$current_dir/openclaw/skills" ]; then
      printf '%s\n' "$current_dir/openclaw/skills"
      return
    fi
    local parent_dir=""
    parent_dir="$(dirname "$current_dir")"
    [ "$parent_dir" = "$current_dir" ] && break
    current_dir="$parent_dir"
    i=$((i + 1))
  done
}

list_bundled_skill_names() {
  local bundled_dir="$1"
  [ -n "$bundled_dir" ] || return
  [ -d "$bundled_dir" ] || return

  for skill_dir in "$bundled_dir"/*/; do
    [ -d "$skill_dir" ] || continue
    if [ -f "${skill_dir}SKILL.md" ]; then
      basename "$skill_dir"
    fi
  done | sort
}

resolve_enabled_bundled_skill_names() {
  local raw_tokens="$1"
  local bundled_dir="$2"
  local available=""
  available="$(list_bundled_skill_names "$bundled_dir")"
  local tokens=""
  tokens="$(split_skill_tokens "$raw_tokens")"

  [ -n "$tokens" ] || return 0

  if printf '%s\n' "$tokens" | grep -Eiq '^(all|\*)$'; then
    if [ -n "$available" ]; then
      printf '%s\n' "$available"
      return
    fi
    echo "  ⚠️  Cannot resolve bundled skills for 'all'. Set OPENCLAW_BUNDLED_SKILLS_DIR or pass explicit skill names." >&2
    return
  fi

  while IFS= read -r token; do
    [ -n "$token" ] || continue
    if [ -n "$available" ]; then
      if printf '%s\n' "$available" | grep -Fxq "$token"; then
        printf '%s\n' "$token"
      else
        echo "  ⚠️  Unknown bundled skill '$token', ignoring" >&2
      fi
    else
      printf '%s\n' "$token"
    fi
  done <<< "$tokens"
}

build_skills_json() {
  local workspace_dir="$1"
  local bundled_raw="$2"
  local bundled_dir="$3"

  local workspace_skills=""
  workspace_skills="$(list_workspace_skill_names "$workspace_dir")"
  local bundled_skills=""
  bundled_skills="$(resolve_enabled_bundled_skill_names "$bundled_raw" "$bundled_dir")"

  printf '%s\n%s\n' "$workspace_skills" "$bundled_skills" \
    | awk 'NF && !seen[$0]++' \
    | node -e '
const fs = require("fs");
const lines = fs.readFileSync(0, "utf8")
  .split(/\r?\n/)
  .map((line) => line.trim())
  .filter(Boolean);
console.log(JSON.stringify(Array.from(new Set(lines))));
'
}

[ -z "$1" ] && usage
AGENT_ID="$1"
shift

BIND_CHANNEL=""
BIND_ACCOUNT=""
BUILTIN_SKILLS_RAW=""
while [ $# -gt 0 ]; do
  case "$1" in
    --bind)
      [ -z "$2" ] && { echo "❌ --bind requires <channel>:<accountId>"; exit 1; }
      BIND_CHANNEL="${2%%:*}"
      BIND_ACCOUNT="${2#*:}"
      shift 2
      ;;
    --builtin-skills)
      [ -z "$2" ] && { echo "❌ --builtin-skills requires <skill1,skill2|all>"; exit 1; }
      BUILTIN_SKILLS_RAW="$2"
      shift 2
      ;;
    *)
      echo "❌ Unknown option: $1"
      usage
      ;;
  esac
done

# 验证 workspace 存在
WORKSPACE="$OPENCLAW_HOME/workspace-$AGENT_ID"
if [ ! -d "$WORKSPACE" ]; then
  echo "❌ Workspace not found: $WORKSPACE"
  echo "   Create the workspace first, then run this script."
  exit 1
fi

BUILTIN_FILE="$WORKSPACE/BUILTIN_SKILLS"
if [ -z "$BUILTIN_SKILLS_RAW" ] && [ -f "$BUILTIN_FILE" ]; then
  BUILTIN_SKILLS_RAW="$(cat "$BUILTIN_FILE")"
fi

BUNDLED_SKILLS_DIR="$(find_bundled_skills_dir)"
SKILLS_JSON="$(build_skills_json "$WORKSPACE" "$BUILTIN_SKILLS_RAW" "$BUNDLED_SKILLS_DIR")"

# 验证 openclaw.json 存在
if [ ! -f "$CONFIG_PATH" ]; then
  echo "❌ Config not found: $CONFIG_PATH"
  exit 1
fi

# 检查 agent 是否已存在
if node -e "
  const c = JSON.parse(require('fs').readFileSync('$CONFIG_PATH','utf8'));
  const exists = (c.agents?.list || []).some(a => a.id === '$AGENT_ID');
  process.exit(exists ? 0 : 1);
" 2>/dev/null; then
  echo "❌ Agent '$AGENT_ID' already exists in openclaw.json"
  exit 1
fi

echo "📦 Adding agent: $AGENT_ID"

# 更新 openclaw.json
SKILLS_JSON="$SKILLS_JSON" node -e "
  const fs = require('fs');
  const c = JSON.parse(fs.readFileSync('$CONFIG_PATH','utf8'));
  const agentSkills = JSON.parse(process.env.SKILLS_JSON || '[]');

  // 1. 添加到 agents.list
  if (!c.agents) c.agents = {};
  if (!c.agents.list) c.agents.list = [];
  c.agents.list.push({
    id: '$AGENT_ID',
    name: '$AGENT_ID',
    workspace: '~/.openclaw/workspace-$AGENT_ID',
    skills: agentSkills
  });

  // 2. 更新 Main Agent 的 allowAgents
  const main = c.agents.list.find(a => a.id === 'main');
  if (main) {
    if (!main.subagents) main.subagents = {};
    if (!main.subagents.allowAgents) main.subagents.allowAgents = [];
    if (!main.subagents.allowAgents.includes('$AGENT_ID')) {
      main.subagents.allowAgents.push('$AGENT_ID');
    }
  }

  // 3. 如果需要绑定渠道
  const bindChannel = '$BIND_CHANNEL';
  const bindAccount = '$BIND_ACCOUNT';
  if (bindChannel) {
    if (!c.bindings) c.bindings = [];
    c.bindings.push({
      agentId: '$AGENT_ID',
      match: { channel: bindChannel, accountId: bindAccount },
      comment: '$AGENT_ID direct channel binding'
    });
  }

  fs.writeFileSync('$CONFIG_PATH', JSON.stringify(c, null, 2) + '\n');
"

echo "  ✅ Added to agents.list"
echo "  ✅ Updated Main Agent allowAgents"
echo "  ✅ Skill filter applied (workspace skills + selected bundled skills)"

if [ -n "$BIND_CHANNEL" ]; then
  echo "  ✅ Added binding: $BIND_CHANNEL:$BIND_ACCOUNT"
fi

# 更新 Main Agent 的 MEMORY.md（团队花名册）
MAIN_MEMORY="$OPENCLAW_HOME/workspace-main/MEMORY.md"
if [ -f "$MAIN_MEMORY" ]; then
  ROUTE_MODE="spawn"
  [ -n "$BIND_CHANNEL" ] && ROUTE_MODE="both"
  BOUND_CHANNELS="—"
  [ -n "$BIND_CHANNEL" ] && BOUND_CHANNELS="$BIND_CHANNEL"

  # 在花名册表格末尾添加新行
  if grep -q "^| $AGENT_ID " "$MAIN_MEMORY" 2>/dev/null; then
    echo "  ⚠️  Agent already in MEMORY.md roster, skipping"
  else
    ROSTER_ROW="| $AGENT_ID | $AGENT_ID | (update specialty) | $ROUTE_MODE | $BOUND_CHANNELS | active |"
    TMP_MEMORY="$(mktemp "${MAIN_MEMORY}.tmp.XXXXXX")"
    awk -v row="$ROSTER_ROW" '
      BEGIN { inserted = 0 }
      /^## Notes/ && inserted == 0 { print row; inserted = 1 }
      { print }
      END { if (inserted == 0) print row }
    ' "$MAIN_MEMORY" > "$TMP_MEMORY"
    mv "$TMP_MEMORY" "$MAIN_MEMORY"
    echo "  ✅ Updated Main Agent MEMORY.md roster"
  fi
fi

echo ""
echo "✅ Agent '$AGENT_ID' registered successfully!"
echo ""
echo "⚠️  Restart Gateway to apply changes: ./scripts/dev.sh gateway"
