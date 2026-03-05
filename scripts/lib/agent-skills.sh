#!/bin/bash
# agent-skills.sh - 统一计算 Agent 的技能白名单

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

resolve_builtin_skill_tokens() {
  local agent_id="$1"
  local explicit_tokens="$2"
  local builtin_file="$3"
  local project_root="$4"

  local requested=""
  if [ -n "$explicit_tokens" ]; then
    requested="$explicit_tokens"
  elif [ -f "$builtin_file" ]; then
    requested="$(cat "$builtin_file")"
  elif [ "$agent_id" = "main" ]; then
    requested="all"
  fi

  [ -n "$requested" ] || return 0

  local available
  available="$(list_builtin_skill_names "$project_root")"

  local raw_tokens
  raw_tokens="$(split_skill_tokens "$requested")"

  if printf '%s\n' "$raw_tokens" | grep -Eiq '^(all|\*)$'; then
    printf '%s\n' "$available"
    return
  fi

  while IFS= read -r token; do
    [ -n "$token" ] || continue
    if printf '%s\n' "$available" | grep -Fxq "$token"; then
      printf '%s\n' "$token"
    else
      echo "  ⚠️  Unknown bundled skill '$token' for agent '$agent_id', ignoring" >&2
    fi
  done <<< "$raw_tokens"
}

resolve_agent_skill_lines() {
  local agent_id="$1"
  local workspace_dir="$2"
  local explicit_builtin_tokens="$3"
  local builtin_file="$4"
  local project_root="$5"

  local workspace_skills
  workspace_skills="$(list_workspace_skill_names "$workspace_dir")"

  local builtin_skills
  builtin_skills="$(resolve_builtin_skill_tokens \
    "$agent_id" \
    "$explicit_builtin_tokens" \
    "$builtin_file" \
    "$project_root")"

  printf '%s\n%s\n' "$workspace_skills" "$builtin_skills" | awk 'NF && !seen[$0]++'
}

resolve_agent_skills_json() {
  local agent_id="$1"
  local workspace_dir="$2"
  local explicit_builtin_tokens="$3"
  local builtin_file="$4"
  local project_root="$5"

  resolve_agent_skill_lines \
    "$agent_id" \
    "$workspace_dir" \
    "$explicit_builtin_tokens" \
    "$builtin_file" \
    "$project_root" \
    | node -e '
const fs = require("fs");
const lines = fs.readFileSync(0, "utf8")
  .split(/\r?\n/)
  .map((line) => line.trim())
  .filter(Boolean);
console.log(JSON.stringify(Array.from(new Set(lines))));
'
}
