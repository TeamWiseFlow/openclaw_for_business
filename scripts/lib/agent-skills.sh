#!/bin/bash
# agent-skills.sh - 统一计算 Agent 的技能过滤配置
#
# 设计理念（OFB）：
#   两种技能解析模式，由 SOUL.md 中的 crew-type 决定：
#
#   inherit 模式（对内 Crew，crew-type: internal）：
#   - 每个 Agent 默认都使用「全局基线技能集」（见 list_default_global_skill_names）
#   - 项目级 / add-on 全局 skills 不自动继承；需在 BUILTIN_SKILLS 中显式声明
#   - self-improving 仍在基线技能中，确保对内 Crew 保留自我改进能力
#   - 可通过 BUILTIN_SKILLS（或显式参数）在基线之上追加 bundled skills
#   - 可通过 DENIED_SKILLS（或显式参数）从最终列表中排除技能
#
#   declare 模式（对外 Crew，crew-type: external）：
#   - 仅使用 DECLARED_SKILLS 文件中明确声明的技能
#   - 不继承基线技能，不继承全局共享技能
#   - 不支持 DENIED_SKILLS（无需排除，因为只包含声明的技能）
#   - workspace 专属技能仍然可用（追加到声明列表末尾）
#
#   最终总是写入 agents.list[].skills，避免"空 skills 字段 => 全量技能泄露"
#   resolve_agent_skills_json 返回：
#       JSON 数组   → Agent 最终可见 skills

set -e

split_skill_tokens() {
  local raw="$1"
  printf '%s\n' "$raw" \
    | sed 's/#.*$//' \
    | tr ',' '\n' \
    | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
    | awk 'NF'
}

# 从 SOUL.md 读取 crew-type 声明
# 返回: "internal" 或 "external"（未声明时默认 "external"，更安全）
resolve_crew_type() {
  local soul_file="$1"

  if [ ! -f "$soul_file" ]; then
    printf 'external'
    return
  fi

  local crew_type
  crew_type="$(grep -m1 '^crew-type:' "$soul_file" 2>/dev/null | sed 's/^crew-type:[[:space:]]*//' | tr -d '[:space:]')"

  case "$crew_type" in
    internal) printf 'internal' ;;
    external) printf 'external' ;;
    *) printf 'external' ;;  # 未声明或未知类型，默认 external（安全兜底）
  esac
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

# 读取对外 Crew 的声明式技能列表（DECLARED_SKILLS 文件）
list_declared_skill_names() {
  local declared_file="$1"

  if [ ! -f "$declared_file" ]; then
    return
  fi

  split_skill_tokens "$(cat "$declared_file")" \
    | grep -Ev '^(self-improving|self-improve)$' \
    | sort -u
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

# 计算 Agent 的技能过滤配置（内部使用）
# 模式由 crew-type 决定：
#   internal → inherit 模式（基线 + 额外 - 拒绝 + workspace）
#   external → declare 模式（仅 DECLARED_SKILLS + workspace）
resolve_agent_skills_json() {
  local agent_id="$1"
  local workspace_dir="$2"
  local explicit_builtin_tokens="$3"
  local builtin_file="$4"
  local explicit_denied_tokens="$5"
  local denied_file="$6"
  local project_root="$7"
  local openclaw_home="${8:-$HOME/.openclaw}"

  # 读取 crew 类型
  local soul_file="$workspace_dir/SOUL.md"
  local crew_type
  crew_type="$(resolve_crew_type "$soul_file")"

  local workspace_skills
  workspace_skills="$(list_workspace_skill_names "$workspace_dir")"

  if [ "$crew_type" = "external" ]; then
    # ── declare 模式（对外 Crew）──
    # 仅使用 DECLARED_SKILLS 文件中的技能 + workspace 专属技能
    local declared_file="$workspace_dir/DECLARED_SKILLS"
    local declared_skills
    declared_skills="$(list_declared_skill_names "$declared_file")"

    printf '%s\n%s\n' "$declared_skills" "$workspace_skills" \
      | grep -Ev '^(self-improving|self-improve)$' \
      | awk 'NF && !seen[$0]++' \
      | node -e '
const fs = require("fs");
const lines = fs.readFileSync(0, "utf8")
  .split(/\r?\n/)
  .map((line) => line.trim())
  .filter(Boolean);
console.log(JSON.stringify(Array.from(new Set(lines))));
'
    return
  fi

  # ── inherit 模式（对内 Crew）──
  local default_builtins=""
  default_builtins="$(list_default_global_skill_names)"

  local additional_builtins=""
  additional_builtins="$(resolve_additional_builtin_skill_names \
    "$explicit_builtin_tokens" \
    "$builtin_file" \
    "$project_root")"

  local merged_global_skills=""
  merged_global_skills="$(printf '%s\n%s\n' "$default_builtins" "$additional_builtins" \
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
