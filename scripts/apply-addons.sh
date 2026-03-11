#!/bin/bash
# apply-addons.sh - 全局 skills 安装 + 通用 addon 加载器
#
# 技能两级体系：
#   - 全局 skills: skills/ (项目根目录) → 安装到 openclaw/skills/（由各 Agent 的 skills allowlist 决定可见范围）
#   - Agent 专属 skills: crews/<template>/skills/ → 已由 setup-crew.sh 安装到 workspace
#
# 每次运行时：
#   1. 恢复 openclaw/ 到干净状态
#   2. 安装全局 skills（项目根目录 skills/）
#   3. 扫描 addons/*/ 目录，对每个 addon 依次执行：
#      a. overrides.sh  — pnpm overrides / 依赖替换（高稳健性）
#      b. patches/*.patch — git patch（逻辑新增，需精确匹配）
#      c. skills/*/SKILL.md — 全局 skill 安装
#      d. crew/*/  — Crew 模板安装 + 可选自动实例化
#
# addon 目录结构：
#   addons/<name>/
#   ├── addon.json          # 元数据（名称、版本、描述）
#   ├── overrides.sh        # 可选：依赖替换脚本
#   ├── patches/*.patch     # 可选：git 补丁
#   ├── skills/*/SKILL.md   # 可选：全局技能（所有 Agent 可见）
#   └── crew/               # 可选：Crew 模板
#       └── <template-id>/
#           ├── SOUL.md ... HEARTBEAT.md  # 模板 workspace 文件
#           ├── DENIED_SKILLS             # 可选：屏蔽特定内置 skill
#           └── skills/*/SKILL.md         # 模板专属技能
set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CREWS_DIR="$PROJECT_ROOT/crews"
ADDONS_DIR="$PROJECT_ROOT/addons"
OPENCLAW_DIR="$PROJECT_ROOT/openclaw"
OPENCLAW_HOME="$HOME/.openclaw"
CONFIG_PATH="$OPENCLAW_HOME/openclaw.json"
HRBP_ADD_AGENT_SCRIPT="$PROJECT_ROOT/crews/hrbp/skills/hrbp-recruit/scripts/add-agent.sh"
GLOBAL_SHARED_SKILLS_FILE="$OPENCLAW_HOME/GLOBAL_SHARED_SKILLS"

GLOBAL_SHARED_SKILLS_RAW=""
append_global_shared_skill() {
  local skill_name="$1"
  [ -n "$skill_name" ] || return 0
  GLOBAL_SHARED_SKILLS_RAW="${GLOBAL_SHARED_SKILLS_RAW}
$skill_name"
}

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
    const clone = (value) => {
      if (value && typeof value === 'object') return JSON.parse(JSON.stringify(value));
      return value;
    };
    let changed = false;

    // 将模板中所有 skills.entries 设置同步到运行配置
    // 确保用户即使更新也能保持精简的内置 skill 集
    if (template.skills?.entries) {
      if (!running.skills) running.skills = {};
      if (!running.skills.entries) running.skills.entries = {};
      for (const [name, entry] of Object.entries(template.skills.entries)) {
        running.skills.entries[name] = entry;
        changed = true;
      }
    }

    // 规范 Feishu 多账号配置：将顶层 single-account 字段下沉到 accounts.*
    // 避免启动时触发 Doctor 迁移提示：
    // \"Moved channels.feishu single-account top-level values into channels.feishu.accounts.default.\"
    const feishu = running.channels?.feishu;
    if (feishu && typeof feishu === 'object' && !Array.isArray(feishu)) {
      const accounts = feishu.accounts;
      if (accounts && typeof accounts === 'object' && !Array.isArray(accounts)) {
        const accountEntries = Object.entries(accounts);
        if (accountEntries.length > 0) {
          const keysToMove = ['dmPolicy', 'allowFrom', 'groupPolicy', 'groupAllowFrom', 'defaultTo'];
          const topLevelValues = {};
          for (const key of keysToMove) {
            if (feishu[key] !== undefined) topLevelValues[key] = feishu[key];
          }
          if (Object.keys(topLevelValues).length > 0) {
            const nextAccounts = {};
            for (const [accountId, rawAccount] of accountEntries) {
              const account =
                rawAccount && typeof rawAccount === 'object' && !Array.isArray(rawAccount)
                  ? { ...rawAccount }
                  : {};
              for (const [key, value] of Object.entries(topLevelValues)) {
                if (account[key] === undefined) account[key] = clone(value);
              }
              nextAccounts[accountId] = account;
            }
            for (const key of Object.keys(topLevelValues)) {
              delete feishu[key];
            }
            feishu.accounts = nextAccounts;
            changed = true;
          }
        }
      }
    }

    if (changed) {
      fs.writeFileSync('$CONFIG_PATH', JSON.stringify(running, null, 2) + '\n');
    }
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
      append_global_shared_skill "$skill_name"
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
        append_global_shared_skill "$skill_name"
      fi
    done
  fi

  # ─── 第四层：Crew 模板安装（crew/ → crews/） ─────────────────
  if [ -d "$addon_dir/crew" ]; then
    echo "  🤖 Installing crew templates..."
    for template_ws in "$addon_dir"/crew/*/; do
      [ -d "$template_ws" ] || continue
      # 需要至少有 SOUL.md 才算有效的模板
      [ -f "${template_ws}SOUL.md" ] || continue

      template_id="$(basename "$template_ws")"

      # 安装模板到 crews/（代码仓中，供 HRBP 使用）
      template_dest="$CREWS_DIR/$template_id"
      if [ -d "$template_dest" ]; then
        echo "    ⚠️  template $template_id already exists in crews/, skipping"
      else
        cp -r "$template_ws" "$template_dest"
        echo "    ✅ template $template_id installed to crews/"
      fi

      # 同步到 hrbp-templates/（运行时副本）
      hrbp_template_dest="$OPENCLAW_HOME/hrbp-templates/$template_id"
      rm -rf "$hrbp_template_dest"
      cp -r "$template_ws" "$hrbp_template_dest"

      # 可选自动实例化（addon.json 中 auto-activate: true���
      auto_activate="$(node -e "
        const a = JSON.parse(require('fs').readFileSync('$addon_dir/addon.json','utf8'));
        console.log(a['auto-activate'] === true ? 'true' : 'false');
      " 2>/dev/null || echo "false")"

      if [ "$auto_activate" = "true" ]; then
        agent_id="$template_id"
        dest="$OPENCLAW_HOME/workspace-$agent_id"

        if [ -d "$dest" ]; then
          echo "    ⚠️  workspace-$agent_id already exists, skipping auto-activate"
        else
          mkdir -p "$dest"
          cp "${template_ws}"*.md "$dest/"
          if [ -f "${template_ws}DENIED_SKILLS" ]; then
            cp "${template_ws}DENIED_SKILLS" "$dest/"
          fi
          # 复制共享协议
          if [ -d "$CREWS_DIR/shared" ]; then
            cp "$CREWS_DIR/shared/"*.md "$dest/"
          fi
          # 复制模板专属 skills（如有）
          if [ -d "${template_ws}skills" ]; then
            cp -r "${template_ws}skills" "$dest/"
          fi
          echo "    ✅ workspace-$agent_id auto-activated"

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
        fi
      else
        echo "    📋 template $template_id ready (use HRBP to instantiate)"
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

# ─── 写入全局共享 skills 清单（供 skills allowlist 计算使用） ──────
mkdir -p "$OPENCLAW_HOME"
printf '%s\n' "$GLOBAL_SHARED_SKILLS_RAW" \
  | awk 'NF && !seen[$0]++' \
  | sort > "$GLOBAL_SHARED_SKILLS_FILE"
GLOBAL_SHARED_COUNT="$(wc -l < "$GLOBAL_SHARED_SKILLS_FILE" | tr -d ' ')"
echo "🧾 Global shared skills catalog updated ($GLOBAL_SHARED_COUNT)"

# ─── 重新同步 agents.list[].skills（纳入最新全局 skills）──────────
if [ -f "$CONFIG_PATH" ] && [ -x "$PROJECT_ROOT/scripts/setup-crew.sh" ]; then
  "$PROJECT_ROOT/scripts/setup-crew.sh"
fi
