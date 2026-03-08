#!/bin/bash
# agent-skills.sh - 统一计算 Agent 的技能过滤配置
#
# 设计理念（新版）：
#   - 默认所有已启用 skill 对全部 Agent 开放（不设 skills 过滤字段）
#   - 如需屏蔽特定 skill，在 workspace 中放置 DENIED_SKILLS 文件（每行一个 skill 名称）
#   - resolve_agent_skills_json 返回：
#       空字符串 ""  → 不需要过滤（删除 skills 字段，所有已启用 skill 可见）
#       JSON 数组   → 只显示指定 skill（用于有 denial list 的 agent）

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
#   空字符串 ""  → 不设 skills 过滤（默认开放全部已启用 skill）
#   JSON 数组   → 明确的 allowlist（用于有 denied skill 的 agent）
resolve_agent_skills_json() {
  local agent_id="$1"
  local workspace_dir="$2"
  local explicit_denied_tokens="$3"
  local denied_file="$4"
  local project_root="$5"

  local denied_names
  denied_names="$(resolve_denied_skill_names \
    "$agent_id" \
    "$explicit_denied_tokens" \
    "$denied_file")"

  # 无屏蔽列表 → 不需要设置 skills 过滤，返回空字符串
  if [ -z "$denied_names" ]; then
    printf ""
    return 0
  fi

  # 有屏蔽列表 → 计算 allowlist = (所有内置 skill - denied) + workspace skills
  local all_builtins
  all_builtins="$(list_builtin_skill_names "$project_root")"

  local allowed_builtins=""
  while IFS= read -r skill; do
    [ -n "$skill" ] || continue
    if ! printf '%s\n' "$denied_names" | grep -Fxq "$skill"; then
      allowed_builtins="$allowed_builtins"$'\n'"$skill"
    fi
  done <<< "$all_builtins"

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
