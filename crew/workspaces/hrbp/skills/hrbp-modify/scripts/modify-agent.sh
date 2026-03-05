#!/bin/bash
# modify-agent.sh - 修改 Agent 的渠道绑定
# 用法: bash ./skills/hrbp-modify/scripts/modify-agent.sh <agent-id> [--bind <channel>:<accountId>] [--unbind <channel>]
set -e

OPENCLAW_HOME="$HOME/.openclaw"
CONFIG_PATH="$OPENCLAW_HOME/openclaw.json"

usage() {
  echo "Usage: $0 <agent-id> [--bind <channel>:<accountId>] [--unbind <channel>]"
  echo ""
  echo "Options:"
  echo "  --bind <channel>:<accountId>  Add/update channel binding (Mode B)"
  echo "  --unbind <channel>            Remove channel binding"
  echo ""
  echo "Examples:"
  echo "  $0 developer --bind wechat:wx_xxx"
  echo "  $0 developer --unbind wechat"
  exit 1
}

[ -z "$1" ] && usage
AGENT_ID="$1"
shift

BIND_CHANNEL=""
BIND_ACCOUNT=""
UNBIND_CHANNEL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --bind)
      [ -z "$2" ] && { echo "❌ --bind requires <channel>:<accountId>"; exit 1; }
      BIND_CHANNEL="${2%%:*}"
      BIND_ACCOUNT="${2#*:}"
      shift 2
      ;;
    --unbind)
      [ -z "$2" ] && { echo "❌ --unbind requires <channel>"; exit 1; }
      UNBIND_CHANNEL="$2"
      shift 2
      ;;
    *)
      echo "❌ Unknown option: $1"
      usage
      ;;
  esac
done

[ -z "$BIND_CHANNEL" ] && [ -z "$UNBIND_CHANNEL" ] && {
  echo "❌ Must specify --bind or --unbind"
  usage
}

# 验证 openclaw.json 存在
if [ ! -f "$CONFIG_PATH" ]; then
  echo "❌ Config not found: $CONFIG_PATH"
  exit 1
fi

# 验证 agent 存在
if ! node -e "
  const c = JSON.parse(require('fs').readFileSync('$CONFIG_PATH','utf8'));
  const exists = (c.agents?.list || []).some(a => a.id === '$AGENT_ID');
  process.exit(exists ? 0 : 1);
" 2>/dev/null; then
  echo "❌ Agent '$AGENT_ID' not found in openclaw.json"
  exit 1
fi

echo "🔧 Modifying agent: $AGENT_ID"

node -e "
  const fs = require('fs');
  const c = JSON.parse(fs.readFileSync('$CONFIG_PATH','utf8'));
  if (!c.bindings) c.bindings = [];

  const unbindChannel = '$UNBIND_CHANNEL';
  const bindChannel = '$BIND_CHANNEL';
  const bindAccount = '$BIND_ACCOUNT';

  // Remove binding
  if (unbindChannel) {
    const before = c.bindings.length;
    c.bindings = c.bindings.filter(b =>
      !(b.agentId === '$AGENT_ID' && b.match?.channel === unbindChannel)
    );
    if (c.bindings.length < before) {
      console.log('  ✅ Removed binding: ' + unbindChannel);
    } else {
      console.log('  ⚠️  No binding found for ' + unbindChannel);
    }
  }

  // Add binding
  if (bindChannel) {
    // Remove existing binding for same agent+channel
    c.bindings = c.bindings.filter(b =>
      !(b.agentId === '$AGENT_ID' && b.match?.channel === bindChannel)
    );
    c.bindings.push({
      agentId: '$AGENT_ID',
      match: { channel: bindChannel, accountId: bindAccount },
      comment: '$AGENT_ID direct channel binding'
    });
    console.log('  ✅ Added binding: ' + bindChannel + ':' + bindAccount);
  }

  fs.writeFileSync('$CONFIG_PATH', JSON.stringify(c, null, 2) + '\n');
"

# 更新 Main Agent 的 MEMORY.md
MAIN_MEMORY="$OPENCLAW_HOME/workspace-main/MEMORY.md"
if [ -f "$MAIN_MEMORY" ]; then
  # 确定新的路由模式
  HAS_BINDING=$(node -e "
    const c = JSON.parse(require('fs').readFileSync('$CONFIG_PATH','utf8'));
    const has = (c.bindings || []).some(b => b.agentId === '$AGENT_ID');
    console.log(has ? 'yes' : 'no');
  ")
  if [ "$HAS_BINDING" = "yes" ]; then
    ROUTE_MODE="both"
  else
    ROUTE_MODE="spawn"
  fi

  # 更新花名册中的路由模式（如果 agent 存在的话）
  if grep -q "^| $AGENT_ID " "$MAIN_MEMORY" 2>/dev/null; then
    echo "  ✅ Updated Main Agent MEMORY.md (route mode: $ROUTE_MODE)"
  fi
fi

echo ""
echo "✅ Agent '$AGENT_ID' modified successfully!"
echo ""
echo "⚠️  Restart Gateway to apply changes: ./scripts/dev.sh gateway"
