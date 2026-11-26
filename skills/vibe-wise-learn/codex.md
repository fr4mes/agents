# VibeWise in Codex

These notes adapt Claude Code tool and command names for Codex. They don't change
the learning behavior; follow SKILL.md and its guides as written.

- Commands: `/vibe-wise-learn` is `$vibe-wise-learn`; `/vibe-wise-reset` is
  `$vibe-wise-reset`.
- Paths: guides sit beside this file in the installed `vibe-wise-learn` skill.
- Files: where the guides say Read or Glob, use your file-reading and search tools.
  Reading plugin guides with a shell command is fine. Check optional learner-state
  files with a conditional that succeeds when they're missing.
- Choices: AskUserQuestion doesn't exist here. If a native question tool such as
  `request_user_input` is available, use it with the same options; otherwise ask
  one plain-text question with the options listed. Then end your turn and wait.
- Restoration: install.sh registers the SessionStart hook for both tools. After compaction, search progress.md for pending decisions before acting.
- Replies: present each checkpoint or question once, at the end of your reply,
  with its options beneath it. Don't restate it in a separate message, add a
  closing line after it, or quote these guides to the learner.
