#!/bin/bash
# setup-crew.sh - 多 Agent 系统安装脚本
# 将 crews/ 中的内置模板、共享协议、模板库部署到 ~/.openclaw/
# 幂等设计：已存在的 workspace 不会覆盖（除非 --force）
set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CREWS_DIR="$PROJECT_ROOT/crews"
OPENCLAW_HOME="$HOME/.openclaw"
CONFIG_PATH="$OPENCLAW_HOME/openclaw.json"
FORCE=false

# 内置 Crew 列表（全局唯一，不可删除，不可多实例）
BUILTIN_CREWS="main hrbp it-engineer"
SYNC_TEAM_DIRECTORY_SCRIPT="$CREWS_DIR/hrbp/skills/hrbp-common/scripts/sync-team-directory.sh"

source "$SCRIPT_DIR/lib/agent-skills.sh"

DENIED_OVERRIDES=""

usage() {
  echo "Usage: $0 [--force] [--denied-skills <agent-id>:<skill1,skill2>]"
  echo ""
  echo "Options:"
  echo "  --force                              Overwrite existing workspace files"
  echo "  --denied-skills <agent-id>:<skills>  Override denied skills for one agent"
  echo ""
  echo "Examples:"
  echo "  $0"
  echo "  $0 --force"
  echo "  $0 --denied-skills hrbp:apple-notes,slack"
  echo "  $0 --denied-skills main:slack --denied-skills hrbp:github,coding-agent"
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --force)
      FORCE=true
      shift
      ;;
    --denied-skills)
      [ -z "$2" ] && { echo "❌ --denied-skills requires <agent-id>:<skills>"; usage; }
      case "$2" in
        *:*)
          DENIED_OVERRIDES="${DENIED_OVERRIDES}
$2"
          ;;
        *)
          echo "❌ Invalid format for --denied-skills: $2"
          echo "   Expected: <agent-id>:<skill1,skill2>"
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

resolve_denied_override_for_agent() {
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
  done <<< "$DENIED_OVERRIDES"
}

sync_agent_skill_filter() {
  local agent_id="$1"
  local agent_override=""
  agent_override="$(resolve_denied_override_for_agent "$agent_id")"

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

  local denied_file="$workspace_dir/DENIED_SKILLS"
  local skills_result=""
  skills_result="$(resolve_agent_skills_json \
    "$agent_id" \
    "$workspace_dir" \
    "$agent_override" \
    "$denied_file" \
    "$PROJECT_ROOT")"

  # 空字符串 → 不设 skills 过滤（删除 skills 字段，所有已启用 skill 可见）
  # JSON 数组  → 写入明确的 allowlist
  AGENT_ID="$agent_id" AGENT_SKILLS_RESULT="$skills_result" node -e "
    const fs = require('fs');
    const c = JSON.parse(fs.readFileSync('$CONFIG_PATH', 'utf8'));
    const list = c.agents?.list || [];
    const idx = list.findIndex((entry) => entry.id === process.env.AGENT_ID);
    if (idx >= 0) {
      const skillsResult = process.env.AGENT_SKILLS_RESULT || '';
      if (skillsResult.trim()) {
        // 有明确的 allowlist → 写入 skills 字段
        list[idx] = { ...list[idx], skills: JSON.parse(skillsResult) };
      } else {
        // 无过滤 → 删除 skills 字段，让 openclaw 默认开放所有已启用 skill
        const { skills: _removed, ...rest } = list[idx];
        list[idx] = rest;
      }
      fs.writeFileSync('$CONFIG_PATH', JSON.stringify(c, null, 2) + '\\n');
    }
  "
}

if [ ! -d "$CREWS_DIR" ]; then
  echo "❌ crews/ directory not found at $CREWS_DIR"
  exit 1
fi

echo "📦 Setting up Agent System (crews)..."

# ─── 1. 安装内置 Crew workspace（main / hrbp / it-engineer） ────
for agent_id in $BUILTIN_CREWS; do
  agent_dir="$CREWS_DIR/$agent_id"
  [ -d "$agent_dir" ] || continue
  dest="$OPENCLAW_HOME/workspace-$agent_id"

  if [ -d "$dest" ] && [ "$FORCE" != "true" ]; then
    echo "  ⚠️  workspace-$agent_id already exists, skipping (use --force to overwrite)"
    continue
  fi

  mkdir -p "$dest"
  cp "$agent_dir"/*.md "$dest/"
  # 复制 DENIED_SKILLS（如有）
  if [ -f "$agent_dir/DENIED_SKILLS" ]; then
    cp "$agent_dir/DENIED_SKILLS" "$dest/"
  fi
  # 复制 Agent 专属 skills（如有）
  if [ -d "$agent_dir/skills" ]; then
    cp -r "$agent_dir/skills" "$dest/"
  fi
  echo "  ✅ workspace-$agent_id installed"
done

# ─── 2. 复制共享协议到每个已安装的内置 workspace ─────────────────
for agent_id in $BUILTIN_CREWS; do
  dest="$OPENCLAW_HOME/workspace-$agent_id"
  if [ -d "$dest" ] && [ -d "$CREWS_DIR/shared" ]; then
    cp "$CREWS_DIR/shared/"*.md "$dest/"
  fi
done
echo "  ✅ Shared protocols (RULES.md, TEMPLATES.md) copied"

# ─── 3. 同步模板库到 hrbp-templates/（供 HRBP 运行时参考） ──────
TEMPLATE_DEST="$OPENCLAW_HOME/hrbp-templates"
mkdir -p "$TEMPLATE_DEST"
# 复制所有模板目录（包括 _template 脚手架和官方模板）
for template_dir in "$CREWS_DIR"/*/; do
  [ -d "$template_dir" ] || continue
  template_id="$(basename "$template_dir")"
  # 跳过 shared/ 目录
  [ "$template_id" = "shared" ] && continue
  # 同步模板（总是覆盖——模板由代码仓控制）
  rm -rf "$TEMPLATE_DEST/$template_id"
  cp -r "$template_dir" "$TEMPLATE_DEST/$template_id"
done
# 同步 index.md
if [ -f "$CREWS_DIR/index.md" ]; then
  cp "$CREWS_DIR/index.md" "$TEMPLATE_DEST/index.md"
fi
echo "  ✅ Template library synced to $TEMPLATE_DEST"

# ─── 4. 更新 openclaw.json（合并内置 Crew + skills 过滤） ────────
if [ -f "$CONFIG_PATH" ]; then
  echo "  📝 Merging agent config into openclaw.json..."

  MAIN_OVERRIDE="$(resolve_denied_override_for_agent "main")"
  HRBP_OVERRIDE="$(resolve_denied_override_for_agent "hrbp")"
  IT_OVERRIDE="$(resolve_denied_override_for_agent "it-engineer")"

  MAIN_SKILLS_RESULT="$(resolve_agent_skills_json \
    "main" \
    "$OPENCLAW_HOME/workspace-main" \
    "$MAIN_OVERRIDE" \
    "$OPENCLAW_HOME/workspace-main/DENIED_SKILLS" \
    "$PROJECT_ROOT")"
  HRBP_SKILLS_RESULT="$(resolve_agent_skills_json \
    "hrbp" \
    "$OPENCLAW_HOME/workspace-hrbp" \
    "$HRBP_OVERRIDE" \
    "$OPENCLAW_HOME/workspace-hrbp/DENIED_SKILLS" \
    "$PROJECT_ROOT")"
  IT_SKILLS_RESULT="$(resolve_agent_skills_json \
    "it-engineer" \
    "$OPENCLAW_HOME/workspace-it-engineer" \
    "$IT_OVERRIDE" \
    "$OPENCLAW_HOME/workspace-it-engineer/DENIED_SKILLS" \
    "$PROJECT_ROOT")"

  MAIN_SKILLS_RESULT="$MAIN_SKILLS_RESULT" HRBP_SKILLS_RESULT="$HRBP_SKILLS_RESULT" IT_SKILLS_RESULT="$IT_SKILLS_RESULT" node -e "
    const fs = require('fs');
    const c = JSON.parse(fs.readFileSync('$CONFIG_PATH', 'utf8'));

    const applySkills = (entry, skillsResult) => {
      const result = (skillsResult || '').trim();
      if (result) {
        return { ...entry, skills: JSON.parse(result) };
      }
      // 无过滤 → 删除 skills 字段
      const { skills: _removed, ...rest } = entry;
      return rest;
    };

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
      const mergedAllowAgents = Array.from(new Set([...allowAgents, 'main', 'hrbp', 'it-engineer']));
      const base = {
        ...prev,
        id: 'main',
        default: prev.default ?? true,
        name: prev.name || 'Main Agent',
        workspace: prev.workspace || '~/.openclaw/workspace-main',
        subagents: {
          ...(prev.subagents || {}),
          allowAgents: mergedAllowAgents,
        },
      };
      return applySkills(base, process.env.MAIN_SKILLS_RESULT);
    });

    upsertAgent('hrbp', (prev) => {
      const base = {
        ...prev,
        id: 'hrbp',
        name: prev.name || 'HRBP',
        workspace: prev.workspace || '~/.openclaw/workspace-hrbp',
      };
      return applySkills(base, process.env.HRBP_SKILLS_RESULT);
    });

    upsertAgent('it-engineer', (prev) => {
      const base = {
        ...prev,
        id: 'it-engineer',
        name: prev.name || 'IT Engineer',
        workspace: prev.workspace || '~/.openclaw/workspace-it-engineer',
      };
      return applySkills(base, process.env.IT_SKILLS_RESULT);
    });

    // 配置飞书多账户 -> Agent 绑定（模式 B：渠道直连）
    if (!Array.isArray(c.bindings) || c.bindings.length === 0) {
      c.bindings = [
        { agentId: 'main', comment: 'main-bot -> Main Agent', match: { channel: 'feishu', accountId: 'main-bot' } },
        { agentId: 'hrbp', comment: 'hrbp-bot -> HRBP Agent', match: { channel: 'feishu', accountId: 'hrbp-bot' } },
        { agentId: 'it-engineer', comment: 'it-engineer-bot -> IT Engineer Agent', match: { channel: 'feishu', accountId: 'it-engineer-bot' } }
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
  echo "  ✅ Agent skill filters synchronized"
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
echo "  Workspaces:  $OPENCLAW_HOME/workspace-main/, workspace-hrbp/, workspace-it-engineer/"
echo "  Templates:   $OPENCLAW_HOME/hrbp-templates/"
echo "  Config:      $CONFIG_PATH"

if [ -f "$SYNC_TEAM_DIRECTORY_SCRIPT" ]; then
  bash "$SYNC_TEAM_DIRECTORY_SCRIPT" >/dev/null 2>&1 || {
    echo "  ⚠️  Failed to sync TEAM_DIRECTORY.md"
  }
fi
