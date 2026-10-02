# agents

Source of truth for agent terminal setup: skills, plugins, MCP servers, and
config shared by Claude Code and Codex on this machine.

## Tool parity

Every change MUST land for Claude Code and Codex in the same commit. A skill,
MCP server, permission, or config change that only one tool gets is
incomplete. Where one tool lacks the feature, the change MUST reach the same
outcome another way (for example, a Claude Code hook in place of Codex's
`enabled_tools`) and the README MUST say how.

OpenCode is unmaintained. `install.sh` still links skills into
`~/.config/opencode/skills`, but changes need not reach OpenCode, and new
features such as MCP servers are not set up for it.

## Layout

- `skills/<name>/SKILL.md` — one directory per skill, in the standard
  `SKILL.md` format both tools understand. Optional `references/`,
  `scripts/`, `assets/` subdirectories are supported per the spec.
- `plugins/` — reserved for later. Claude Code and Codex plugins use
  different formats, so each tool gets its own subdirectory and its own
  install step when needed.
- `mcp/<server>/allowed-tools.txt` — the tools an MCP server may expose to
  agents, one name per line.
- `mcp/<server>/oauth-scopes.txt` — the OAuth scopes both tools request, one
  per line.
- `claude/hooks/` — Claude Code hook scripts.
- `install.sh` — installs everything above into both tools. Re-run it after
  any change. Run it from the main checkout, not a worktree: the symlinks
  point at the checkout it runs from.

## Install

```sh
./install.sh
```

## MCP servers

### Atlassian (Jira, Confluence)

The official [Atlassian Rovo MCP server](https://developer.atlassian.com/cloud/rovo-mcp/)
at `https://mcp.atlassian.com/v2/mcp?tools=all`. It authenticates with OAuth
2.1, so you never handle an API token, and it only sees what your Atlassian
account can see. `?tools=all` exposes every tool by name, so the allowlist
can filter them. Without it, the server hides most tools behind the
`executeRead`/`executeWrite` meta-tools.

Access is read-only for Jira and Confluence. `transitionJiraIssue` is the only
write allowed. Two layers enforce this:

- `oauth-scopes.txt` limits the token to Jira and Confluence read and search,
  plus `write:jira`. The token cannot delete, manage projects, write to
  Confluence, or reach other Atlassian products.
- `allowed-tools.txt` blocks every tool not listed, including write tools
  Atlassian adds later. `transitionJiraIssue` needs `write:jira`, which also
  permits creating, editing, and commenting on issues, so this list is the
  only thing that blocks those.

To change access, edit either file, re-run `./install.sh`, and log in again
if the scopes changed:

```sh
codex mcp login atlassian
claude    # then run /mcp, pick atlassian, Authenticate
```

Revoke access at id.atlassian.com → Security → Connected apps.

## Claude Code configuration

`install.sh` changes these files:

- `~/.claude/skills/<name>` — symlinks to `skills/<name>`.
- `~/.claude/hooks/mcp-tool-allowlist.sh` — symlink to
  `claude/hooks/mcp-tool-allowlist.sh`.
- `~/.claude.json` — user-scope MCP servers, with `oauth.scopes` from
  `oauth-scopes.txt`. A server whose config differs from this repo is
  replaced, which drops its OAuth token.
- `~/.claude/settings.json` — one `PreToolUse` hook entry per allowlisted
  server. Re-runs replace the entry; the rest of the file is untouched.

Claude Code has no per-server tool filter. The hook denies any tool not in
`mcp/<server>/allowed-tools.txt`. A `permissions.deny` list only blocks tools
named in it, so the hook also blocks tools nobody listed in advance. Hooks
run in every permission mode, including `--dangerously-skip-permissions`.
The hook matcher also covers the Atlassian connectors synced from claude.ai
(`mcp__claude_ai_Atlassian__*`), which have their own OAuth login. The hook
needs `jq`.

## Codex configuration

`install.sh` changes these files:

- `~/.agents/skills/<name>` — symlinks to `skills/<name>`.
- `~/.codex/config.toml` — one block per MCP server between
  `# BEGIN agents: …` and `# END agents: …` markers, regenerated on re-runs.
  Don't edit inside the markers. If `[mcp_servers.<name>]` already exists
  outside the block, the install stops instead of writing invalid TOML.

Codex filters tools natively with `enabled_tools`, generated from
`allowed-tools.txt`, so blocked tools are never shown to the model. `scopes`
is generated from `oauth-scopes.txt`.

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
  no findings are in context, and shows the review after posting. Then moves
  the PR's Jira ticket to `En desarrollo`, or to the status the user names,
  unless told not to.
- `re-review` — user-invoked. Follow-up review after the author addressed a
  prior one: runs `/code-review` against the merge-base, grades each prior
  finding against the current code and the author's replies (fixed, partial,
  open, withdrawn), and lists new findings apart.
- `review-qa` — user-invoked. Reviews the PR of every SUP ticket in Jira's
  `QA técnico` status, least QA Tec Time left first, then least Time to
  resolution. Takes how many PRs to review at once and reviews each PR with
  its ticket as the spec: `/code-review` the first time, `/re-review` once it
  has prior reviews. Never downloads attachments. Needs
  the Atlassian MCP server and local clones under `~/plibots/<repo>`.

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
  Codex-specific `agents/openai.yaml` display metadata was dropped; Codex
  reads the `SKILL.md` frontmatter without it.

  Run `/setup-matt-pocock-skills` once in any repo where you use the
  engineering skills above — it sets the issue tracker, triage labels, and
  domain-doc location the others assume.
