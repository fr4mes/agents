#!/usr/bin/env bash
# Installs this repo's skills and MCP servers into Claude Code and Codex.
# Safe to re-run.
set -euo pipefail
shopt -s nullglob

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

link_dir() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    echo "ok      $dst"
    return
  fi
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    echo "skip    $dst (exists, not a symlink)" >&2
    return
  fi
  rm -f "$dst"
  ln -s "$src" "$dst"
  echo "linked  $dst -> $src"
}

install_group() {
  local kind="$1"; shift
  local targets=("$@")
  for skill_dir in "$REPO_DIR/$kind"/*/; do
    local name src
    name="$(basename "${skill_dir%/}")"
    src="${skill_dir%/}"
    for target_root in "${targets[@]}"; do
      link_dir "$src" "$target_root/$name"
    done
  done
}

# Prints a list file's entries: one per line, comments and blanks dropped.
list_entries() {
  sed -e 's/#.*//' -e 's/[[:space:]]//g' "$1" | grep -v '^$'
}

# Claude Code reads ~/.claude/skills/*/SKILL.md.
# Codex reads ~/.agents/skills/*/SKILL.md.
# OpenCode reads ~/.config/opencode/skills/*/SKILL.md. Unmaintained.
install_group skills \
  "$HOME/.claude/skills" \
  "$HOME/.agents/skills" \
  "$HOME/.config/opencode/skills"

ATLASSIAN_MCP_URL="https://mcp.atlassian.com/v2/mcp?tools=all"
ATLASSIAN_ALLOWLIST="$REPO_DIR/mcp/atlassian/allowed-tools.txt"
ATLASSIAN_SCOPES="$REPO_DIR/mcp/atlassian/oauth-scopes.txt"
# Claude Code names claude.ai connectors claude_ai_<Name>, so the hook also
# guards the Atlassian connectors synced from claude.ai.
ATLASSIAN_HOOK_MATCHER='mcp__(atlassian|claude_ai_Atlassian|claude_ai_Atlassian_MCP)__.*'

install_claude_atlassian() {
  if ! command -v claude >/dev/null 2>&1; then
    echo "skip    claude atlassian mcp (claude not installed)" >&2
    return
  fi

  local hooks_dir="$HOME/.claude/hooks"
  mkdir -p "$hooks_dir"
  link_dir "$REPO_DIR/claude/hooks/mcp-tool-allowlist.sh" "$hooks_dir/mcp-tool-allowlist.sh"

  local desired current
  desired="$(jq -cnS --arg url "$ATLASSIAN_MCP_URL" \
    --arg scopes "$(list_entries "$ATLASSIAN_SCOPES" | paste -sd ' ')" \
    '{type: "http", url: $url, oauth: {scopes: $scopes}}')"
  current="$(jq -cS '.mcpServers.atlassian // empty' "$HOME/.claude.json" 2>/dev/null || true)"
  if [ "$current" = "$desired" ]; then
    echo "ok      claude mcp atlassian"
  else
    # Replacing the server drops its OAuth token, so new scopes take effect
    # on the next login.
    if [ -n "$current" ]; then
      claude mcp remove --scope user atlassian >/dev/null
    fi
    claude mcp add-json --scope user atlassian "$desired" >/dev/null
    echo "updated claude mcp atlassian (log in again: claude, then /mcp)"
  fi

  # Replaces this repo's hook entry in ~/.claude/settings.json, leaving the
  # rest of the file untouched.
  local settings="$HOME/.claude/settings.json" tmp
  [ -f "$settings" ] || echo '{}' > "$settings"
  tmp="$(mktemp "$settings.XXXXXX")"
  jq --arg matcher "$ATLASSIAN_HOOK_MATCHER" \
     --arg command "$hooks_dir/mcp-tool-allowlist.sh atlassian" '
    .hooks.PreToolUse = (
      [(.hooks.PreToolUse // [])[]
        | select(any(.hooks[]?; .command | test("mcp-tool-allowlist\\.sh")) | not)]
      + [{matcher: $matcher, hooks: [{type: "command", command: $command}]}]
    )' "$settings" > "$tmp"
  mv "$tmp" "$settings"
  echo "ok      claude PreToolUse allowlist hook"
}

install_codex_atlassian() {
  if ! command -v codex >/dev/null 2>&1; then
    echo "skip    codex atlassian mcp (codex not installed)" >&2
    return
  fi

  local config="$HOME/.codex/config.toml" tmp
  local begin="# BEGIN agents: mcp_servers.atlassian" end="# END agents: mcp_servers.atlassian"
  mkdir -p "$(dirname "$config")"
  touch "$config"

  # Rewrites only the marked block, so entries Codex adds elsewhere survive.
  tmp="$(mktemp "$config.XXXXXX")"
  awk -v begin="$begin" -v end="$end" '
    $0 == begin { skip = 1; next }
    $0 == end { skip = 0; next }
    !skip
  ' "$config" > "$tmp"
  {
    echo
    echo "$begin"
    echo "# Managed by $REPO_DIR/install.sh. Edit mcp/atlassian/*.txt instead."
    echo "[mcp_servers.atlassian]"
    echo "url = \"$ATLASSIAN_MCP_URL\""
    echo "scopes = ["
    list_entries "$ATLASSIAN_SCOPES" | sed 's/.*/  "&",/'
    echo "]"
    echo "enabled_tools = ["
    list_entries "$ATLASSIAN_ALLOWLIST" | sed 's/.*/  "&",/'
    echo "]"
    echo "$end"
  } >> "$tmp"
  # Collapses the blank lines left behind by earlier runs.
  cat -s "$tmp" > "$tmp.s" && mv "$tmp.s" "$tmp"
  if ! python3 -c 'import sys, tomllib; tomllib.load(open(sys.argv[1], "rb"))' "$tmp"; then
    rm -f "$tmp"
    echo "fail    codex mcp atlassian ($config would be invalid TOML; is [mcp_servers.atlassian] defined outside the managed block?)" >&2
    return 1
  fi
  chmod --reference="$config" "$tmp"
  if cmp -s "$tmp" "$config"; then
    rm -f "$tmp"
    echo "ok      codex mcp atlassian"
    return
  fi
  mv "$tmp" "$config"
  echo "updated codex mcp atlassian (log in again: codex mcp login atlassian)"
}

install_claude_atlassian
install_codex_atlassian

# Plugin formats differ per tool (Claude Code marketplace bundles vs. Codex
# plugins), so there is no single shared symlink target yet. Add per-tool
# install logic here once plugins/<tool>/<name> exists.
