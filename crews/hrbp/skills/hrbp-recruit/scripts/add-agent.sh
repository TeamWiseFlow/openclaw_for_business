#!/bin/bash
# add-agent.sh - 注册新 Agent 到 openclaw.json
# 用法: bash ./skills/hrbp-recruit/scripts/add-agent.sh <agent-id> [--bind <channel>:<accountId>] [--builtin-skills <skill1,skill2|all>] [--template-id <template-id>] [--note <text>]
# skill 规则：
#   - 默认基线技能（OFB 全局）始终生效
#   - addon / 项目级全局 skills 默认追加给所有 Agent
#   - --builtin-skills / BUILTIN_SKILLS 用于在基线上追加技能（非替换）
#   - DENIED_SKILLS 最终裁剪
set -e

OPENCLAW_HOME="$HOME/.openclaw"
CONFIG_PATH="$OPENCLAW_HOME/openclaw.json"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SYNC_TEAM_DIRECTORY_SCRIPT="$SCRIPT_DIR/../../hrbp-common/scripts/sync-team-directory.sh"

source "$SCRIPT_DIR/../../hrbp-common/scripts/lib.sh"

usage() {
  echo "Usage: $0 <agent-id> [--bind <channel>:<accountId>] [--builtin-skills <skill1,skill2|all>] [--template-id <template-id>] [--note <text>]"
  echo ""
  echo "Options:"
  echo "  --bind <channel>:<accountId>  Bind agent to a channel (Mode B direct routing)"
  echo "  --builtin-skills <skills>     Additional bundled skills on top of OFB baseline (comma-separated)"
  echo "  --template-id <template-id>   Source template id (for HRBP memory registry)"
  echo "  --note <text>                 Optional note (for HRBP memory registry)"
  echo ""
  echo "Examples:"
  echo "  $0 developer"
  echo "  $0 developer --builtin-skills browser-guide,summarize"
  echo "  $0 short-video-ops --template-id content-writer --note '短视频运营岗'"
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

list_default_global_skill_names() {
  cat <<'EOF'
1password
healthcheck
model-usage
nano-pdf
skill-creator
ordercli
session-logs
tmux
weather
xurl
video-frames
self-improving
EOF
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

list_global_shared_skill_names() {
  local bundled_dir="$1"
  local shared_file="$OPENCLAW_HOME/GLOBAL_SHARED_SKILLS"

  # 优先读取运行时清单（由 apply-addons.sh 维护）
  if [ -f "$shared_file" ]; then
    split_skill_tokens "$(cat "$shared_file")" | sort -u
    return
  fi

  # 兜底：若可定位到项目根目录，则扫描项目级与 addon 级全局 skills
  local project_root=""
  if [ -n "$bundled_dir" ] && [ -d "$bundled_dir" ]; then
    local openclaw_dir
    openclaw_dir="$(dirname "$bundled_dir")"
    local candidate_root
    candidate_root="$(dirname "$openclaw_dir")"
    if [ -d "$candidate_root/skills" ] || [ -d "$candidate_root/addons" ]; then
      project_root="$candidate_root"
    fi
  fi

  [ -n "$project_root" ] || return 0

  {
    if [ -d "$project_root/skills" ]; then
      for skill_dir in "$project_root"/skills/*/; do
        [ -d "$skill_dir" ] || continue
        if [ -f "${skill_dir}SKILL.md" ]; then
          basename "$skill_dir"
        fi
      done
    fi

    if [ -d "$project_root/addons" ]; then
      for skill_dir in "$project_root"/addons/*/skills/*/; do
        [ -d "$skill_dir" ] || continue
        if [ -f "${skill_dir}SKILL.md" ]; then
          basename "$skill_dir"
        fi
      done
    fi
  } | sort -u
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

  local disabled_skills=""
  disabled_skills="$(
    CONFIG_PATH="$CONFIG_PATH" node -e '
const fs = require("fs");
const path = process.env.CONFIG_PATH;
if (!path || !fs.existsSync(path)) process.exit(0);
try {
  const c = JSON.parse(fs.readFileSync(path, "utf8"));
  const entries = c?.skills?.entries || {};
  for (const [name, entry] of Object.entries(entries)) {
    if (entry && entry.enabled === false) console.log(name);
  }
} catch (_) {}
'
  )"

  for skill_dir in "$bundled_dir"/*/; do
    [ -d "$skill_dir" ] || continue
    if [ -f "${skill_dir}SKILL.md" ]; then
      local skill_name
      skill_name="$(basename "$skill_dir")"
      if [ -n "$disabled_skills" ] && printf '%s\n' "$disabled_skills" | grep -Fxq "$skill_name"; then
        continue
      fi
      printf '%s\n' "$skill_name"
    fi
  done | sort
}

resolve_denied_skill_names() {
  local denied_file="$1"
  [ -f "$denied_file" ] || return 0
  split_skill_tokens "$(cat "$denied_file")"
}

resolve_additional_bundled_skill_names() {
  local raw_tokens="$1"
  local bundled_dir="$2"
  local tokens=""
  tokens="$(split_skill_tokens "$raw_tokens")"

  [ -n "$tokens" ] || return 0

  if printf '%s\n' "$tokens" | grep -Eiq '^(all|\*)$'; then
    local available=""
    available="$(list_bundled_skill_names "$bundled_dir")"
    if [ -n "$available" ]; then
      printf '%s\n' "$available"
      return
    fi
    echo "  ⚠️  Cannot resolve bundled skills for 'all'. Set OPENCLAW_BUNDLED_SKILLS_DIR or pass explicit skill names." >&2
    return
  fi

  while IFS= read -r token; do
    [ -n "$token" ] || continue
    printf '%s\n' "$token"
  done <<< "$tokens"
}

build_agent_skills_json() {
  local workspace_dir="$1"
  local bundled_raw="$2"
  local denied_names="$3"
  local bundled_dir="$4"

  local baseline_bundled=""
  baseline_bundled="$(list_default_global_skill_names)"
  local additional_bundled=""
  additional_bundled="$(resolve_additional_bundled_skill_names "$bundled_raw" "$bundled_dir")"
  local global_shared_skills=""
  global_shared_skills="$(list_global_shared_skill_names "$bundled_dir")"

  local merged_global_skills=""
  merged_global_skills="$(printf '%s\n%s\n%s\n' "$baseline_bundled" "$additional_bundled" "$global_shared_skills" \
    | awk 'NF && !seen[$0]++')"

  local allowed_bundled=""
  if [ -n "$denied_names" ]; then
    while IFS= read -r skill; do
      [ -n "$skill" ] || continue
      if ! printf '%s\n' "$denied_names" | grep -Fxq "$skill"; then
        allowed_bundled="$allowed_bundled"$'\n'"$skill"
      fi
    done <<< "$merged_global_skills"
  else
    allowed_bundled="$merged_global_skills"
  fi

  local workspace_skills=""
  workspace_skills="$(list_workspace_skill_names "$workspace_dir")"

  printf '%s\n%s\n' "$allowed_bundled" "$workspace_skills" \
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

validate_agent_id "$AGENT_ID"

BIND_CHANNEL=""
BIND_ACCOUNT=""
BUILTIN_SKILLS_RAW=""
TEMPLATE_ID=""
RECRUIT_NOTE=""
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
    --template-id)
      [ -z "$2" ] && { echo "❌ --template-id requires <template-id>"; exit 1; }
      TEMPLATE_ID="$2"
      shift 2
      ;;
    --note)
      [ -z "$2" ] && { echo "❌ --note requires <text>"; exit 1; }
      RECRUIT_NOTE="$2"
      shift 2
      ;;
    *)
      echo "❌ Unknown option: $1"
      usage
      ;;
  esac
done

[ -n "$TEMPLATE_ID" ] || TEMPLATE_ID="$AGENT_ID"
[ -n "$RECRUIT_NOTE" ] || RECRUIT_NOTE="auto-registered by hrbp-recruit"

sanitize_inline_text() {
  local raw="$1"
  printf '%s\n' "$raw" \
    | tr '\n' ' ' \
    | sed 's/[|]/\//g; s/[[:space:]]\+/ /g; s/^ //; s/ $//'
}

TEMPLATE_ID_SANITIZED="$(sanitize_inline_text "$TEMPLATE_ID")"
RECRUIT_NOTE_SANITIZED="$(sanitize_inline_text "$RECRUIT_NOTE")"
TODAY_DATE="$(date +%F)"

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
DENIED_FILE="$WORKSPACE/DENIED_SKILLS"
DENIED_NAMES="$(resolve_denied_skill_names "$DENIED_FILE")"
SKILLS_JSON="[]"
SKILLS_MODE="baseline-default"

SKILLS_JSON="$(build_agent_skills_json \
  "$WORKSPACE" \
  "$BUILTIN_SKILLS_RAW" \
  "$DENIED_NAMES" \
  "$BUNDLED_SKILLS_DIR")"

HAS_ADDITIONAL_BUILTINS="false"
if [ -n "$(split_skill_tokens "$BUILTIN_SKILLS_RAW")" ]; then
  HAS_ADDITIONAL_BUILTINS="true"
fi

if [ "$HAS_ADDITIONAL_BUILTINS" = "true" ] && [ -n "$DENIED_NAMES" ]; then
  SKILLS_MODE="baseline-plus-additional-minus-denied"
elif [ "$HAS_ADDITIONAL_BUILTINS" = "true" ]; then
  SKILLS_MODE="baseline-plus-additional"
elif [ -n "$DENIED_NAMES" ]; then
  SKILLS_MODE="baseline-minus-denied"
fi

# 验证 openclaw.json 存在
if [ ! -f "$CONFIG_PATH" ]; then
  echo "❌ Config not found: $CONFIG_PATH"
  exit 1
fi

# 检查 agent 是否已存在
if AGENT_ID="$AGENT_ID" CONFIG_PATH="$CONFIG_PATH" node -e "
  const c = JSON.parse(require('fs').readFileSync(process.env.CONFIG_PATH, 'utf8'));
  const exists = (c.agents?.list || []).some(a => a.id === process.env.AGENT_ID);
  process.exit(exists ? 0 : 1);
" 2>/dev/null; then
  echo "❌ Agent '$AGENT_ID' already exists in openclaw.json"
  exit 1
fi

echo "📦 Adding agent: $AGENT_ID"

# 更新 openclaw.json
AGENT_ID="$AGENT_ID" BIND_CHANNEL="$BIND_CHANNEL" BIND_ACCOUNT="$BIND_ACCOUNT" CONFIG_PATH="$CONFIG_PATH" SKILLS_JSON="$SKILLS_JSON" node -e "
  const fs = require('fs');
  const c = JSON.parse(fs.readFileSync(process.env.CONFIG_PATH, 'utf8'));
  const agentSkills = JSON.parse(process.env.SKILLS_JSON || '[]');
  const agentId = process.env.AGENT_ID;

  // 1. 添加到 agents.list
  if (!c.agents) c.agents = {};
  if (!c.agents.list) c.agents.list = [];
  const newAgent = {
    id: agentId,
    name: agentId,
    workspace: '~/.openclaw/workspace-' + agentId,
    skills: agentSkills,
  };
  c.agents.list.push(newAgent);

  // 2. 更新 Main Agent 的 allowAgents
  const main = c.agents.list.find(a => a.id === 'main');
  if (main) {
    if (!main.subagents) main.subagents = {};
    if (!main.subagents.allowAgents) main.subagents.allowAgents = [];
    if (!main.subagents.allowAgents.includes(agentId)) {
      main.subagents.allowAgents.push(agentId);
    }
  }

  // 3. 如果需要绑定渠道
  const bindChannel = process.env.BIND_CHANNEL || '';
  const bindAccount = process.env.BIND_ACCOUNT || '';
  if (bindChannel) {
    if (!c.bindings) c.bindings = [];
    c.bindings.push({
      agentId,
      match: { channel: bindChannel, accountId: bindAccount },
      comment: agentId + ' direct channel binding'
    });
  }

  fs.writeFileSync(process.env.CONFIG_PATH, JSON.stringify(c, null, 2) + '\n');
"

echo "  ✅ Added to agents.list"
echo "  ✅ Updated Main Agent allowAgents"
case "$SKILLS_MODE" in
  baseline-default)
    echo "  ✅ Skill scope: OFB baseline bundled skills + global shared skills + workspace skills"
    ;;
  baseline-minus-denied)
    echo "  ✅ Skill scope: baseline bundled + global shared - DENIED_SKILLS + workspace skills"
    ;;
  baseline-plus-additional)
    echo "  ✅ Skill scope: baseline bundled + global shared + additional bundled + workspace skills"
    ;;
  baseline-plus-additional-minus-denied)
    echo "  ✅ Skill scope: baseline bundled + global shared + additional bundled - DENIED_SKILLS + workspace skills"
    ;;
esac

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

# 更新 HRBP 的 MEMORY.md（Instance Registry + Operation History）
HRBP_MEMORY="$OPENCLAW_HOME/workspace-hrbp/MEMORY.md"
if [ -f "$HRBP_MEMORY" ]; then
  REGISTRY_ROW="| $AGENT_ID | $TEMPLATE_ID_SANITIZED | $TODAY_DATE | $RECRUIT_NOTE_SANITIZED |"
  HISTORY_LINE="- $TODAY_DATE: 招募 $AGENT_ID ($TEMPLATE_ID_SANITIZED) - $RECRUIT_NOTE_SANITIZED"

  if grep -Fq "| $AGENT_ID |" "$HRBP_MEMORY" 2>/dev/null; then
    echo "  ⚠️  Agent already in HRBP MEMORY registry, skipping registry row"
  else
    TMP_HRBP_MEMORY="$(mktemp "${HRBP_MEMORY}.tmp.XXXXXX")"
    awk -v row="$REGISTRY_ROW" '
      BEGIN { inserted = 0 }
      /^## Operation History/ && inserted == 0 { print row; inserted = 1 }
      { print }
      END { if (inserted == 0) print row }
    ' "$HRBP_MEMORY" > "$TMP_HRBP_MEMORY"
    mv "$TMP_HRBP_MEMORY" "$HRBP_MEMORY"
    echo "  ✅ Updated HRBP MEMORY instance registry"
  fi

  if grep -Fqx "$HISTORY_LINE" "$HRBP_MEMORY" 2>/dev/null; then
    echo "  ⚠️  Recruit history entry already exists in HRBP MEMORY, skipping"
  else
    TMP_HRBP_HISTORY="$(mktemp "${HRBP_MEMORY}.tmp.XXXXXX")"
    awk -v line="$HISTORY_LINE" '
      BEGIN { inserted = 0 }
      /^## Operation History/ {
        print
        print ""
        print line
        inserted = 1
        next
      }
      { print }
      END {
        if (inserted == 0) {
          print ""
          print "## Operation History"
          print ""
          print line
        }
      }
    ' "$HRBP_MEMORY" > "$TMP_HRBP_HISTORY"
    mv "$TMP_HRBP_HISTORY" "$HRBP_MEMORY"
    echo "  ✅ Updated HRBP MEMORY operation history"
  fi
fi

if [ -f "$SYNC_TEAM_DIRECTORY_SCRIPT" ]; then
  OPENCLAW_HOME="$OPENCLAW_HOME" CONFIG_PATH="$CONFIG_PATH" bash "$SYNC_TEAM_DIRECTORY_SCRIPT" >/dev/null 2>&1 || {
    echo "  ⚠️  Failed to sync TEAM_DIRECTORY.md"
  }
fi

echo ""
echo "✅ Agent '$AGENT_ID' registered successfully!"
echo ""
echo "⚠️  Restart Gateway to apply changes: ./scripts/dev.sh gateway"
