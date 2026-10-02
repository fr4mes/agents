#!/usr/bin/env bash
# PreToolUse hook. Denies any MCP tool call whose tool name is not listed in
# mcp/<list>/allowed-tools.txt. Runs in every permission mode, bypass included.
# Usage: mcp-tool-allowlist.sh <list>
set -euo pipefail

deny() {
  jq -n --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

if ! command -v jq >/dev/null 2>&1; then
  echo "mcp-tool-allowlist: jq is required" >&2
  exit 2
fi

list="${1:?usage: mcp-tool-allowlist.sh <list>}"
repo_dir="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)"
allowlist="$repo_dir/mcp/$list/allowed-tools.txt"
[ -r "$allowlist" ] || deny "MCP allowlist not found: $allowlist"

tool_name="$(jq -r '.tool_name // empty')"
[ -n "$tool_name" ] || deny "MCP allowlist: hook input has no tool_name"
tool="${tool_name##*__}"

if grep -qxF -- "$tool" < <(sed -e 's/#.*//' -e 's/[[:space:]]//g' "$allowlist"); then
  exit 0
fi
deny "$tool is not in the $list MCP allowlist ($allowlist)"
