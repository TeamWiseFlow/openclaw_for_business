#!/bin/bash
# remove-agent.sh - 从 openclaw.json 移除 Agent（workspace 归档不删除）
# 用法: bash ./skills/hrbp-remove/scripts/remove-agent.sh <agent-id>
set -e

OPENCLAW_HOME="$HOME/.openclaw"
CONFIG_PATH="$OPENCLAW_HOME/openclaw.json"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SYNC_TEAM_DIRECTORY_SCRIPT="$SCRIPT_DIR/../../hrbp-common/scripts/sync-team-directory.sh"

usage() {
  echo "Usage: $0 <agent-id>"
  echo ""
  echo "Removes an agent from openclaw.json and archives its workspace."
  echo "Protected agents (main, hrbp, it-engineer) cannot be removed."
  exit 1
}

validate_agent_id() {
  local id="$1"
  if ! printf '%s\n' "$id" | grep -Eq '^[a-z0-9][a-z0-9-]*$'; then
    echo "❌ Invalid agent-id: $id"
    echo "   Expected: lowercase letters, numbers, hyphens (e.g. customer-service-a)"
    exit 1
  fi
}

[ -z "$1" ] && usage
AGENT_ID="$1"

validate_agent_id "$AGENT_ID"

# 安全检查：保护 main、hrbp 和 it-engineer
if [ "$AGENT_ID" = "main" ] || [ "$AGENT_ID" = "hrbp" ] || [ "$AGENT_ID" = "it-engineer" ]; then
  echo "❌ Agent '$AGENT_ID' is protected and cannot be removed."
  exit 1
fi

# 验证 openclaw.json 存在
if [ ! -f "$CONFIG_PATH" ]; then
  echo "❌ Config not found: $CONFIG_PATH"
  exit 1
fi

# 验证 agent 存在
if ! AGENT_ID="$AGENT_ID" CONFIG_PATH="$CONFIG_PATH" node -e "
  const c = JSON.parse(require('fs').readFileSync(process.env.CONFIG_PATH, 'utf8'));
  const exists = (c.agents?.list || []).some(a => a.id === process.env.AGENT_ID);
  process.exit(exists ? 0 : 1);
" 2>/dev/null; then
  echo "❌ Agent '$AGENT_ID' not found in openclaw.json"
  exit 1
fi

echo "🗑️  Removing agent: $AGENT_ID"

# 1. 从 openclaw.json 移除
AGENT_ID="$AGENT_ID" CONFIG_PATH="$CONFIG_PATH" node -e "
  const fs = require('fs');
  const c = JSON.parse(fs.readFileSync(process.env.CONFIG_PATH, 'utf8'));
  const agentId = process.env.AGENT_ID;

  // 从 agents.list 移除
  if (c.agents?.list) {
    c.agents.list = c.agents.list.filter(a => a.id !== agentId);
  }

  // 从 Main Agent 的 allowAgents 移除
  const main = (c.agents?.list || []).find(a => a.id === 'main');
  if (main?.subagents?.allowAgents) {
    main.subagents.allowAgents = main.subagents.allowAgents.filter(id => id !== agentId);
  }

  // 从 bindings 移除
  if (c.bindings) {
    c.bindings = c.bindings.filter(b => b.agentId !== agentId);
  }

  fs.writeFileSync(process.env.CONFIG_PATH, JSON.stringify(c, null, 2) + '\n');
"
echo "  ✅ Removed from openclaw.json"

# 2. 归档 workspace（不直接删除）
WORKSPACE="$OPENCLAW_HOME/workspace-$AGENT_ID"
if [ -d "$WORKSPACE" ]; then
  ARCHIVE_DIR="$OPENCLAW_HOME/archived"
  mkdir -p "$ARCHIVE_DIR"
  TIMESTAMP=$(date +%Y%m%d-%H%M%S)
  ARCHIVE_DEST="$ARCHIVE_DIR/workspace-$AGENT_ID-$TIMESTAMP"
  mv "$WORKSPACE" "$ARCHIVE_DEST"
  echo "  ✅ Workspace archived to: $ARCHIVE_DEST"
else
  echo "  ⚠️  No workspace found at $WORKSPACE"
fi

# 3. 更新 Main Agent 的 MEMORY.md
MAIN_MEMORY="$OPENCLAW_HOME/workspace-main/MEMORY.md"
if [ -f "$MAIN_MEMORY" ]; then
  if grep -q "^| $AGENT_ID " "$MAIN_MEMORY" 2>/dev/null; then
    TMP_MEMORY="$(mktemp "${MAIN_MEMORY}.tmp.XXXXXX")"
    grep -v "^| $AGENT_ID " "$MAIN_MEMORY" > "$TMP_MEMORY"
    mv "$TMP_MEMORY" "$MAIN_MEMORY"
    echo "  ✅ Removed from Main Agent MEMORY.md roster"
  fi
fi

if [ -f "$SYNC_TEAM_DIRECTORY_SCRIPT" ]; then
  OPENCLAW_HOME="$OPENCLAW_HOME" CONFIG_PATH="$CONFIG_PATH" bash "$SYNC_TEAM_DIRECTORY_SCRIPT" >/dev/null 2>&1 || {
    echo "  ⚠️  Failed to sync TEAM_DIRECTORY.md"
  }
fi

echo ""
echo "✅ Agent '$AGENT_ID' removed successfully!"
echo "   Workspace archived (not deleted) — can be recovered from:"
echo "   $ARCHIVE_DIR/"
echo ""
echo "⚠️  Restart Gateway to apply changes: ./scripts/dev.sh gateway"
