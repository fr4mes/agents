# agents

Source of truth for agent terminal setup: skills, plugins, and config shared
across every Claude Code and OpenCode instance on this machine.

## Layout

- `skills/<name>/SKILL.md` — one directory per skill, in the standard
  `SKILL.md` format both tools understand. Optional `references/`,
  `scripts/`, `assets/` subdirectories are supported per the spec.
- `plugins/` — reserved for later. Claude Code and OpenCode plugins use
  incompatible formats (marketplace bundles vs. JS/TS hook scripts), so
  each tool gets its own subdirectory and its own install step when needed.
- `install.sh` — symlinks everything above into the places each tool reads
  from. Re-run it after adding or editing a skill.

## Install

```sh
./install.sh
```

This symlinks each `skills/<name>` into `~/.claude/skills/<name>` and
`~/.config/opencode/skills/<name>`. Both Claude Code and OpenCode read
`~/.claude/skills`, so one canonical copy here covers both tools.

## Adding a skill

Create `skills/<name>/SKILL.md` with YAML frontmatter (`name`, `description`),
then run `./install.sh`.

## Commits

Commits MUST follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/):

```
<type>(<scope>): <subject>
```

The subject MUST be imperative and lowercase. Types in use: `feat`, `fix`,
`docs`, `refactor`, `chore`. The scope SHOULD be the skill directory the
change touches, and MAY be omitted for repo-wide changes.

```
feat(post-pr-review): request changes on a PR in Spanish
docs: require conventional commits
chore: re-link skills after rename
```

A body is for a fact the diff cannot show, such as how a script was
verified. Everything the diff already says stays out of it.

## Local skills

Authored here, not vendored.

- `post-pr-review` — user-invoked. Requests changes on a GitHub PR, carrying
  the findings as inline comments in Spanish, anchored to lines its
  `scripts/anchors.sh` proves are in the diff. Runs `/code-review` first when
  no findings are in context, and shows the review before posting.
- `re-review` — user-invoked. Follow-up review after the author addressed a
  prior one: runs `/code-review` against the merge-base, grades each prior
  finding against the current code (fixed, partial, open), and lists new
  findings apart.

## Vendored skills

- `unslop` — from [cursor/plugins](https://github.com/cursor/plugins/blob/main/pstack/skills/unslop/SKILL.md).
- `grill-with-docs`, `resolving-merge-conflicts`, `tdd`, `to-spec`,
  `implement`, `code-review`, `codebase-design`, `wait-what`, `teach`,
  `improve-codebase-architecture`, `diagnosing-bugs`, `wayfinder`, `handoff`,
  `writing-for-agents`
  — from [mattpocock/skills](https://github.com/mattpocock/skills), plus the
  skills they depend on via internal `Skill` tool calls: `grilling`,
  `domain-modeling`, `research`, `prototype` (pulled in by `grill-with-docs`,
  `wayfinder`, and `improve-codebase-architecture`), and
  `setup-matt-pocock-skills` (the per-repo config wizard `code-review` and
  `to-spec` point you to when `docs/agents/issue-tracker.md` is missing).
  Codex-specific `agents/openai.yaml` display metadata was dropped since
  it's not used by Claude Code or OpenCode.

  Run `/setup-matt-pocock-skills` once in any repo where you use the
  engineering skills above — it sets the issue tracker, triage labels, and
  domain-doc location the others assume.
