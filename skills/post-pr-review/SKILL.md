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

Drop every finding about commit messages: their nomenclature, type, scope, subject, or body. This review covers the code the PR changes, so they stay out of the comments and out of the body.

Then list the open threads of any prior review of ours with the query under **Resolving what the author fixed**. A thread whose finding the new run no longer raises is fixed. Keep its `id`, since step 6 resolves it.

Done when every remaining finding carries a file, a line, and the problem it names. A review with no findings has nothing to request changes on, so report that and stop.

### 3. Build the anchor set

Run `scripts/anchors.sh <arg>`. It prints every `path`, `line`, `side` triple the API accepts, one per line. Anything outside that set comes back as a 422.

Place each finding on one of those triples. A finding pointing at a line the set omits moves to the nearest listed line in the same file, and its comment says which line it means. A finding about a file with no listed line goes to the body.

Done when every finding holds an anchor from the script's output or has moved to the body. Account for all of them.

### 4. Write the comments

Spanish prose. Identifiers, paths, commands, and code stay verbatim in whatever language the codebase uses.

Here and in the body, computer science terms stay in English, the way the developers reading the review say them out loud: `merge`, `commit`, `push`, `branch`, `build`, `deploy`, `type`, `mock`, `flag`, `hook`, `linter`, `snapshot`. Where the sentence needs a verb, conjugate the English one: `mergear`, `commitear`, `pushear`, `deployar`, `testear`. Never reach for the dictionary translation, which reads as a machine wrote it: not `mezclar` for merge, not `empujar` for push, not `rama` for branch, not `bandera` for flag, not `instantánea` for snapshot.

The dialect is Colombian, never Argentine. Address the author as `usted` and conjugate for it: `revise el orden`, `mueva el guard`, `elimine el cast`, `si prefiere`. Impersonal phrasing beats direct address wherever it fits: `conviene mover el guard arriba`, `falta cubrir el caso vacío`. Voseo is out, so no `revisá`, `mové`, `tenés`, `podés`, `fijate`, `mirá`. `Tú` is out with it, so no `puedes`, no `tienes`, no `revisa`. So is Peninsular `vosotros`, `os` and `¿vale?`.

Argentine vocabulary and intensifiers go with the voseo: not `re lento` but `muy lento`, not `capaz que falla` but `puede fallar`, not `está bárbaro` but `está bien`, not `un quilombo` but `un desorden`. Colombian slang stays out too, so no `parce`, no `chévere`, no `de una`. The register is the plain professional Spanish of a Bogotá code review.

Each comment names the problem and the fix in two sentences at most. Where the fix is a literal line replacement, put it in a `suggestion` fenced block so the author can commit it in one click.

Prescribe only what a `suggestion` block could carry. Elsewhere, name the defect and what the code loses by it, and leave the fix to the author. Wording that dictates a condition, a config value, or a code shape gets applied to the letter, so wherever the instruction was narrower than the problem, the next round returns a faithful edit with a fresh hole in it.

Give the reason itself, never the file it came from. `AGENTS.md`, `CLAUDE.md`, and any other instruction file are tooling the author did not write and may not read, so a comment that cites one leaves the finding unexplained. Carry over the reasoning that file gives for the rule. Where it states the rule and no reasoning, name what the code at hand loses by breaking it.

So not this:

> `AGENTS.md` prohíbe el type casting.

but this:

> El cast silencia al compilador, así que el `null` que llega en runtime rompe aquí sin que nada avise antes.

Run `/unslop` over every comment and over the body. Its structural rules carry straight into Spanish: plain words, active voice, no em dashes, sentence case. Its vocabulary list is English, so apply the Spanish equivalents of the same tells (`garantizar`, `crucial`, `robusto`, `en el contexto de`, `cabe destacar que`).

Done when every comment has been through `/unslop`.

### 5. Write the body only when it earns the space

Submit a body when it carries what no single comment can: a pattern spanning several files, what has to land before the PR is mergeable, or which findings from an earlier review the author fixed. Otherwise submit the review with its comments alone, which step 6 supports.

Two things never go in the body:

- Anything a comment already says. Naming the inline findings again, counting them, or announcing that they are commented inline tells the author nothing the comments do not.
- Formatters, linters, type checks, and tests passing. CI reports that.

That cuts a body like this one:

> Los diez hallazgos anteriores están resueltos, y `oxfmt`, `lint` y `tsc` pasan. Quedan tres bloqueantes y un hueco de cobertura. Los bloqueantes son el tipo `WorkPermitAtsStepSnapshot` sin los campos por los que ahora se empareja, la validación nueva que impide re-guardar permisos antiguos, y la aserción del gate de flags que pasa sin comprobar nada. Los tres van comentados en línea.

down to this:

> Los diez hallazgos anteriores están resueltos.

### 6. Post, then show

Make the calls below without asking. The user invoked this skill to post the review, so a confirmation step only stalls it.

Once the review is submitted, print every comment as `path:line side` followed by its text, then the body if there is one, then the threads that resolved as fixed, each as `path:line` with the finding it carried.

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

## Resolving what the author fixed

Review threads have no REST endpoint, so listing and resolving them both go through GraphQL. `<owner>` and `<repo>` are the base repo, from `gh repo view --json owner,name`.

```sh
gh api graphql -f query='
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $number) {
        reviewThreads(first: 100) {
          nodes {
            id
            isResolved
            isOutdated
            comments(first: 1) { nodes { path line originalLine body author { login } } }
          }
        }
      }
    }
  }' -F owner=<owner> -F repo=<repo> -F number=<number>
```

A thread qualifies when it is ours, unresolved, and its finding is absent from the new run. Ours means the login `gh api user --jq .login` prints. `isOutdated` proves nothing on its own, since it says the line moved, not that the problem went away. Read the code at the thread's path before calling the finding fixed. A finding the new run raises again keeps its thread open.

Resolve each qualifying thread once the submit below has succeeded, so a failed submit never leaves the PR with resolved threads and no review:

```sh
gh api graphql -f query='
  mutation($id: ID!) {
    resolveReviewThread(input: { threadId: $id }) { thread { isResolved } }
  }' -F id=<threadId>
```

Resolving needs push access on the repo. A `Resource not accessible` error means the token lacks it, so leave the threads open and tell the user.

## When a call fails

A 422 reading `line must be part of the diff` means the anchor set went stale, almost always a fresh push. Rebuild it from step 3 against the new head and post again.

A create that succeeds while the submit fails leaves a `PENDING` review on the PR. GitHub allows one pending review per user per PR, so clear it before retrying:

```sh
gh api --method DELETE repos/{owner}/{repo}/pulls/<number>/reviews/<id>
```
