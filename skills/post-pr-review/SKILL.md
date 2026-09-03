---
name: post-pr-review
description: Request changes on a GitHub PR with inline comments written in Spanish.
disable-model-invocation: true
---

Requests changes on a GitHub pull request, carrying every finding as a review comment **anchored** to a line the diff actually contains, written in Spanish.

## Process

### 1. Pin the PR

`gh pr view <arg> --json number,url,headRefOid`. Without an argument this resolves the PR of the current branch; with one it takes a number, URL, or branch name. Stop and ask the user if nothing resolves.

Keep `headRefOid`. Passing it as `commit_id` pins the review to the commit the anchors came from, so a push mid-review fails loudly instead of landing comments on moved lines.

### 2. Collect the findings

Reuse the findings already in context from a review run this session. When there are none, run `/code-review` against the PR's merge-base first, then continue here with its output.

Done when every finding carries a file, a line, and the problem it names. A review with no findings has nothing to request changes on, so report that and stop.

### 3. Build the anchor set

Run `scripts/anchors.sh <arg>`. It prints every `path`, `line`, `side` triple the API accepts, one per line. Anything outside that set comes back as a 422.

Place each finding on one of those triples. A finding pointing at a line the set omits moves to the nearest listed line in the same file, and its comment says which line it means. A finding about a file with no listed line goes to the body.

Done when every finding holds an anchor from the script's output or has moved to the body. Account for all of them.

### 4. Write the comments

Spanish prose. Identifiers, paths, commands, and code stay verbatim in whatever language the codebase uses.

Each comment names the problem and the fix in two sentences at most. Where the fix is a literal line replacement, put it in a `suggestion` fenced block so the author can commit it in one click.

Run `/unslop` over every comment and over the body. Its structural rules carry straight into Spanish: plain words, active voice, no em dashes, sentence case. Its vocabulary list is English, so apply the Spanish equivalents of the same tells (`garantizar`, `crucial`, `robusto`, `en el contexto de`, `cabe destacar que`).

Done when every comment has been through `/unslop`.

### 5. Write the body only when it earns the space

Submit a body when it carries what no single comment can: a pattern spanning several files, or what has to land before the PR is mergeable. Otherwise submit the review with its comments alone, which step 6 supports.

### 6. Show, then post

Print every comment as `path:line side` followed by its text, then the body if there is one. Wait for the user's go-ahead before either call below.

## The two calls

`gh api` carries the inline comments, since `gh pr review` has no line anchoring.

Create the review with `event` omitted, which leaves it `PENDING` and takes no body:

```sh
gh api --method POST repos/{owner}/{repo}/pulls/<number>/reviews --input review.json --jq .id
```

```json
{
  "commit_id": "<headRefOid>",
  "comments": [
    { "path": "src/a.ts", "line": 42, "side": "RIGHT", "body": "..." },
    { "path": "src/b.ts", "start_line": 10, "line": 14, "side": "RIGHT", "body": "..." }
  ]
}
```

A multi-line comment uses `start_line` with `line` on one `side`, and both ends need to be in the anchor set.

Then submit it, adding `-f body=...` only when step 5 called for one:

```sh
gh api --method POST repos/{owner}/{repo}/pulls/<number>/reviews/<id>/events -f event=REQUEST_CHANGES
```

Every review submits as `REQUEST_CHANGES`, whatever the severity of the findings.

Two calls rather than one because `body` is required when `REQUEST_CHANGES` rides along with the create call, and optional on submit. The split is what buys a review with no body.

## When a call fails

A 422 reading `line must be part of the diff` means the anchor set went stale, almost always a fresh push. Rebuild it from step 3 against the new head and post again.

A create that succeeds while the submit fails leaves a `PENDING` review on the PR. GitHub allows one pending review per user per PR, so clear it before retrying:

```sh
gh api --method DELETE repos/{owner}/{repo}/pulls/<number>/reviews/<id>
```
