#!/bin/bash
# apply-addons.sh - 全局 skills 安装 + 通用 addon 加载器
#
# 技能两级体系：
#   - 全局 skills: skills/ (项目根目录) → 安装到 openclaw/skills/（默认只有 main agent 会启用，其他 crew 需要额外配置）
#   - Agent 专属 skills: crew/workspaces/<agent>/skills/ → 已由 setup-crew.sh 安装到 workspace
#
# 每次运行时：
#   1. 恢复 openclaw/ 到干净状态
#   2. 安装全局 skills（项目根目录 skills/）
#   3. 扫描 addons/*/ 目录，对每个 addon 依次执行：
#      a. overrides.sh  — pnpm overrides / 依赖替换（高稳健性）
#      b. patches/*.patch — git patch（逻辑新增，需精确匹配）
#      c. skills/*/SKILL.md — 全局 skill 安装
#      d. crew/*/  — 预制 Agent 安装（workspace + Agent 专属 skills）
#
# addon 目录结构：
#   addons/<name>/
#   ├── addon.json          # 元数据（名称、版本、描述）
#   ├── overrides.sh        # 可选：依赖替换脚本
#   ├── patches/*.patch     # 可选：git 补丁
#   ├── skills/*/SKILL.md   # 可选：全局技能（所有 Agent 可见）
#   └── crew/               # 可选：预制 Agent
#       └── <agent-id>/
#           ├── SOUL.md ... HEARTBEAT.md  # workspace 文件
#           ├── DENIED_SKILLS             # 可选：屏蔽特定内置 skill
#           └── skills/*/SKILL.md         # Agent 专属技能
set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CREW_DIR="$PROJECT_ROOT/crew"
ADDONS_DIR="$PROJECT_ROOT/addons"
OPENCLAW_DIR="$PROJECT_ROOT/openclaw"
OPENCLAW_HOME="$HOME/.openclaw"
CONFIG_PATH="$OPENCLAW_HOME/openclaw.json"
HRBP_ADD_AGENT_SCRIPT="$PROJECT_ROOT/crew/workspaces/hrbp/skills/hrbp-recruit/scripts/add-agent.sh"

# ─── 恢复上游到干净状态 ──────────────────────────────────────────
cd "$OPENCLAW_DIR"
git reset --hard HEAD 2>/dev/null || true
cd "$PROJECT_ROOT"

# ─── 同步 skills 禁用配置（从 config-templates 到运行配置）──────
if [ -f "$CONFIG_PATH" ] && [ -f "$PROJECT_ROOT/config-templates/openclaw.json" ]; then
  node -e "
    const fs = require('fs');
    const running = JSON.parse(fs.readFileSync('$CONFIG_PATH', 'utf8'));
    const template = JSON.parse(fs.readFileSync('$PROJECT_ROOT/config-templates/openclaw.json', 'utf8'));

    // 将模板中所有 skills.entries 设置同步到运��配置
    // 确保用户即使更新也能保持精简的内置 skill 集
    if (template.skills?.entries) {
      if (!running.skills) running.skills = {};
      if (!running.skills.entries) running.skills.entries = {};
      for (const [name, entry] of Object.entries(template.skills.entries)) {
        running.skills.entries[name] = entry;
      }
    }

    fs.writeFileSync('$CONFIG_PATH', JSON.stringify(running, null, 2) + '\n');
  "
  echo "📝 Skills configuration synchronized"
fi

# ─── 注入 awada 扩展路径（绝对路径，避免 CWD 依赖）──────────────
AWADA_EXT="$PROJECT_ROOT/awada/awada-extension"
if [ -d "$AWADA_EXT" ] && [ -f "$AWADA_EXT/openclaw.plugin.json" ]; then
  if [ -f "$CONFIG_PATH" ]; then
    node -e "
      const fs = require('fs');
      const config = JSON.parse(fs.readFileSync('$CONFIG_PATH', 'utf8'));
      if (!config.plugins) config.plugins = {};
      if (!config.plugins.load) config.plugins.load = {};
      if (!Array.isArray(config.plugins.load.paths)) config.plugins.load.paths = [];
      const awadaPath = '$AWADA_EXT';
      if (!config.plugins.load.paths.includes(awadaPath)) {
        config.plugins.load.paths.push(awadaPath);
      }
      if (!config.plugins.entries) config.plugins.entries = {};
      if (!config.plugins.entries.awada) {
        config.plugins.entries.awada = { enabled: false };
      }
      fs.writeFileSync('$CONFIG_PATH', JSON.stringify(config, null, 2) + '\n');
    "
    echo "📝 Awada extension path injected"
  fi
fi

# ─── 安装全局共享技能（项目根目录 skills/） ──────���──────────────
GLOBAL_SKILL_COUNT=0
if [ -d "$PROJECT_ROOT/skills" ]; then
  for skill_dir in "$PROJECT_ROOT"/skills/*/; do
    if [ -f "${skill_dir}SKILL.md" ]; then
      skill_name="$(basename "$skill_dir")"
      cp -r "$skill_dir" "$OPENCLAW_DIR/skills/$skill_name"
      GLOBAL_SKILL_COUNT=$((GLOBAL_SKILL_COUNT + 1))
    fi
  done
fi
if [ "$GLOBAL_SKILL_COUNT" -gt 0 ]; then
  echo "📦 Global skills installed ($GLOBAL_SKILL_COUNT)"
fi

# ─── 扫描并加载 addons ──────────────────────────────────────────
if [ ! -d "$ADDONS_DIR" ]; then
  mkdir -p "$ADDONS_DIR"
fi

ADDON_COUNT=0
NEEDS_INSTALL=false

for addon_dir in "$ADDONS_DIR"/*/; do
  [ -d "$addon_dir" ] || continue

  addon_name="$(basename "$addon_dir")"

  # 跳过没有 addon.json 的目录
  if [ ! -f "$addon_dir/addon.json" ]; then
    echo "⚠️  Skipping $addon_name (no addon.json)"
    continue
  fi

  echo "📦 Loading addon: $addon_name"
  ADDON_COUNT=$((ADDON_COUNT + 1))

  # ─── 第一层：overrides（依赖替换，不依赖行号） ────────────────
  if [ -f "$addon_dir/overrides.sh" ]; then
    echo "  🔧 Running overrides..."
    ADDON_DIR="$addon_dir" OPENCLAW_DIR="$OPENCLAW_DIR" bash "$addon_dir/overrides.sh"
    NEEDS_INSTALL=true
  fi

  # ─── 第二层：git patches（精确代码改动） ───────────────────────
  if ls "$addon_dir"/patches/*.patch 1>/dev/null 2>&1; then
    echo "  🩹 Applying patches..."
    cd "$OPENCLAW_DIR"
    for patch in "$addon_dir"/patches/*.patch; do
      echo "    → $(basename "$patch")"
      git apply --3way --ignore-whitespace --whitespace=fix "$patch" || {
        echo "    ❌ Failed to apply $(basename "$patch")"
        echo "       Hint: 上游代码可能已变更，需在 $addon_name 中重新生成此补丁"
        exit 1
      }
    done
    cd "$PROJECT_ROOT"
    NEEDS_INSTALL=true
  fi

  # ─── 第三层：全局 skills 安装 ──────────────────────────────────
  if [ -d "$addon_dir/skills" ]; then
    echo "  📚 Installing global skills..."
    for skill_dir in "$addon_dir"/skills/*/; do
      if [ -f "${skill_dir}SKILL.md" ]; then
        skill_name="$(basename "$skill_dir")"
        echo "    → $skill_name (global)"
        cp -r "$skill_dir" "$OPENCLAW_DIR/skills/$skill_name"
      fi
    done
  fi

  # ─── 第四层：预制 Agent 安装（crew/） ──────────────────────────
  if [ -d "$addon_dir/crew" ]; then
    echo "  🤖 Installing agents..."
    for agent_ws in "$addon_dir"/crew/*/; do
      [ -d "$agent_ws" ] || continue
      # 需要至少有 SOUL.md 才算有效的 agent workspace
      [ -f "${agent_ws}SOUL.md" ] || continue

      agent_id="$(basename "$agent_ws")"
      dest="$OPENCLAW_HOME/workspace-$agent_id"

      # 安装 workspace（不覆盖已存在的）
      if [ -d "$dest" ]; then
        echo "    ⚠️  workspace-$agent_id already exists, skipping"
      else
        mkdir -p "$dest"
        cp "${agent_ws}"*.md "$dest/"
        if [ -f "${agent_ws}DENIED_SKILLS" ]; then
          cp "${agent_ws}DENIED_SKILLS" "$dest/"
        fi
        # 复制共享协议
        if [ -d "$CREW_DIR/shared" ]; then
          cp "$CREW_DIR/shared/"*.md "$dest/"
        fi
        # 复制 Agent 专属 skills（如有）
        if [ -d "${agent_ws}skills" ]; then
          cp -r "${agent_ws}skills" "$dest/"
        fi
        echo "    ✅ workspace-$agent_id installed"
      fi

      # 注册 agent（如果尚未注册）
      if [ -f "$CONFIG_PATH" ]; then
        if ! node -e "
          const c = JSON.parse(require('fs').readFileSync('$CONFIG_PATH','utf8'));
          process.exit((c.agents?.list || []).some(a => a.id === '$agent_id') ? 0 : 1);
        " 2>/dev/null; then
          if [ ! -f "$HRBP_ADD_AGENT_SCRIPT" ]; then
            echo "    ❌ HRBP add-agent script not found: $HRBP_ADD_AGENT_SCRIPT"
            exit 1
          fi
          "$HRBP_ADD_AGENT_SCRIPT" "$agent_id"
          echo "    ✅ agent $agent_id registered"
        fi
      fi
    done
  fi

  echo "  ✅ $addon_name loaded"
done

# 有 overrides 或 patches 时才需要同步依赖
if [ "$NEEDS_INSTALL" = "true" ]; then
  echo "📦 Syncing dependencies..."
  cd "$OPENCLAW_DIR"
  pnpm install --frozen-lockfile=false
  cd "$PROJECT_ROOT"
fi

if [ "$ADDON_COUNT" -gt 0 ]; then
  echo "✅ All addons applied ($ADDON_COUNT loaded)"
else
  echo "📦 No addons found"
fi
