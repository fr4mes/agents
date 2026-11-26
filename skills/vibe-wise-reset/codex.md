# VibeWise Reset in Codex

These notes adapt Claude Code tool and command names for Codex. Follow SKILL.md
as written otherwise.

- Paths: run `scripts/reset.py` using its absolute path under this skill directory. The Learn guide is `../vibe-wise-learn/SKILL.md`.
- Commands: suggest `$vibe-wise-learn` where SKILL.md says `/vibe-wise-learn`.
- Choices: AskUserQuestion doesn't exist here. If a native question tool such as
  `request_user_input` is available, use it with the same options; otherwise ask
  the same question in text. Then end your turn and wait for an explicit answer.
- Replies: ask the confirmation once, at the end of your reply. Don't add a
  closing line after it or quote these guides to the user.
