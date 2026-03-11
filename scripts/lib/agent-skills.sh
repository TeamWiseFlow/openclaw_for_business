#!/bin/bash
# agent-skills.sh - 统一计算 Agent 的技能过滤配置
#
# 设计理念（OFB）：
#   - 每个 Agent 默认都使用「全局基线技能集」（见 list_default_global_skill_names）
#   - add-on / 项目级全局 skills 默认对所有 Agent 开放（见 list_global_shared_skill_names）
#   - 可通过 BUILTIN_SKILLS（或显式参数）在基线之上追加 bundled skills
#   - 可通过 DENIED_SKILLS（或显式参数）从最终列表中排除技能
#   - 最终总是写入 agents.list[].skills，避免“空 skills 字段 => 全量技能泄露”
#   - resolve_agent_skills_json 返回：
#       JSON 数组   → Agent 最终可见 skills（bundled + workspace）

set -e

split_skill_tokens() {
  local raw="$1"
  printf '%s\n' "$raw" \
    | sed 's/#.*$//' \
    | tr ',' '\n' \
    | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
    | awk 'NF'
}

list_builtin_skill_names() {
  local project_root="$1"
  local bundled_root="$project_root/openclaw/skills"

  if [ ! -d "$bundled_root" ]; then
    return
  fi

  for skill_dir in "$bundled_root"/*/; do
    [ -d "$skill_dir" ] || continue
    if [ -f "${skill_dir}SKILL.md" ]; then
      basename "$skill_dir"
    fi
  done | sort
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
  local project_root="$1"
  local openclaw_home="$2"
  local shared_file="$openclaw_home/GLOBAL_SHARED_SKILLS"

  # 优先读取运行时清单（由 apply-addons.sh 维护）
  if [ -f "$shared_file" ]; then
    split_skill_tokens "$(cat "$shared_file")" | sort -u
    return
  fi

  # 兜底：从项目目录扫描「项目级 skills + addon 级 skills」
  # 注意：只扫描 addons/*/skills，不扫描 addons/*/crew/*/skills
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

# 读取额外 bundled skills（来自 BUILTIN_SKILLS 文件或命令行参数）
# 返回：每行一个 skill 名称，空字符串表示无额外追加
resolve_additional_builtin_skill_names() {
  local explicit_tokens="$1"
  local builtin_file="$2"
  local project_root="$3"

  local raw=""
  if [ -n "$explicit_tokens" ]; then
    raw="$explicit_tokens"
  elif [ -f "$builtin_file" ]; then
    raw="$(cat "$builtin_file")"
  fi

  [ -n "$raw" ] || return 0

  local tokens=""
  tokens="$(split_skill_tokens "$raw")"
  [ -n "$tokens" ] || return 0

  # 支持 all/*：扩展为当前可发现的 bundled skills
  if printf '%s\n' "$tokens" | grep -Eiq '^(all|\*)$'; then
    local all_builtins=""
    all_builtins="$(list_builtin_skill_names "$project_root")"
    if [ -n "$all_builtins" ]; then
      printf '%s\n' "$all_builtins"
      return 0
    fi
    echo "  ⚠️  Cannot resolve bundled skills for 'all' (openclaw/skills not found)." >&2
    return 0
  fi

  # 额外技能不做强校验，允许先声明后安装
  printf '%s\n' "$tokens"
}

# 读取需要屏蔽的 skill 列表（来自 DENIED_SKILLS 文件或命令行参数）
# 返回：每行一个 skill 名称，空字符串表示无屏蔽
resolve_denied_skill_names() {
  local agent_id="$1"
  local explicit_tokens="$2"
  local denied_file="$3"

  local raw=""
  if [ -n "$explicit_tokens" ]; then
    raw="$explicit_tokens"
  elif [ -f "$denied_file" ]; then
    raw="$(cat "$denied_file")"
  fi

  [ -n "$raw" ] || return 0

  split_skill_tokens "$raw"
}

# 计算 Agent 的技能过滤配置
# 返回：
#   JSON 数组   → 明确的 allowlist（默认基线 + 额外 - denied + workspace）
resolve_agent_skills_json() {
  local agent_id="$1"
  local workspace_dir="$2"
  local explicit_builtin_tokens="$3"
  local builtin_file="$4"
  local explicit_denied_tokens="$5"
  local denied_file="$6"
  local project_root="$7"
  local openclaw_home="${8:-$HOME/.openclaw}"

  local default_builtins=""
  default_builtins="$(list_default_global_skill_names)"

  local additional_builtins=""
  additional_builtins="$(resolve_additional_builtin_skill_names \
    "$explicit_builtin_tokens" \
    "$builtin_file" \
    "$project_root")"

  local global_shared_skills=""
  global_shared_skills="$(list_global_shared_skill_names "$project_root" "$openclaw_home")"

  local merged_global_skills=""
  merged_global_skills="$(printf '%s\n%s\n%s\n' "$default_builtins" "$additional_builtins" "$global_shared_skills" \
    | awk 'NF && !seen[$0]++')"

  local denied_names
  denied_names="$(resolve_denied_skill_names \
    "$agent_id" \
    "$explicit_denied_tokens" \
    "$denied_file")"

  local allowed_builtins=""
  if [ -n "$denied_names" ]; then
    while IFS= read -r skill; do
      [ -n "$skill" ] || continue
      if ! printf '%s\n' "$denied_names" | grep -Fxq "$skill"; then
        allowed_builtins="$allowed_builtins"$'\n'"$skill"
      fi
    done <<< "$merged_global_skills"
  else
    allowed_builtins="$merged_global_skills"
  fi

  local workspace_skills
  workspace_skills="$(list_workspace_skill_names "$workspace_dir")"

  printf '%s\n%s\n' "$allowed_builtins" "$workspace_skills" \
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
