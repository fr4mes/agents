#!/usr/bin/env bash
# Symlinks this repo's skills/ (and, once populated, plugins/) into every
# agent terminal's config directory. Safe to re-run.
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

# Claude Code reads ~/.claude/skills/*/SKILL.md.
# OpenCode reads ~/.claude/skills/*/SKILL.md, ~/.agents/skills/*/SKILL.md,
# and its own ~/.config/opencode/skills/*/SKILL.md.
install_group skills \
  "$HOME/.claude/skills" \
  "$HOME/.config/opencode/skills"

# Plugin formats differ per tool (Claude Code marketplace bundles vs.
# OpenCode JS/TS hook plugins), so there is no single shared symlink target
# yet. Add per-tool install logic here once plugins/<tool>/<name> exists.
