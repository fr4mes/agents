---
name: re-review
description: Re-review a branch or PR after the author addressed a prior review. Grades each prior finding against the current code and lists new findings apart.
disable-model-invocation: true
---

Follow-up review of a branch or PR whose author pushed fixes for an earlier review. It does two jobs and keeps them apart:

- **Verdict**: grade every prior finding against the current code.
- **New findings**: anything the fresh review raises that no prior finding covers.

## Process

### 1. Collect the prior findings

Take them from the review run earlier in this session. When none are in context, read our unresolved threads on the PR with the query under **Resolving what the author fixed** in `post-pr-review`. Ours means the login `gh api user --jq .login` prints.

Done when every prior finding sits in one list with its file, its line, and the problem it names. With no prior findings there is nothing to verify, so tell the user to run `/code-review` instead and stop.

### 2. Run the fresh review against the merge-base

The fixed point is the PR's merge-base, never the commit the last review saw. A diff that only covers the fix commits hides every unfixed finding in code the author left alone, so those findings look fixed.

Resolve the base with `gh pr view <arg> --json baseRefName`, or take the one the user names. Run `/code-review` against it.

### 3. Grade each prior finding

Read the code at each finding's path at `HEAD` and grade it:

- **Fixed**: the defect is gone.
- **Partial**: the defect is narrower but still present. Name what remains.
- **Open**: the defect is unchanged.

A finding the fresh run did not raise again is still unproven. Reviews vary between runs, so the code is the only evidence. A finding that moved lines keeps its identity; grade it at its new location.

Done when every prior finding carries a grade, and every grade other than **Fixed** says what remains.

### 4. Split out the new findings

A new finding is one from step 2 that no prior finding covers. A step 2 finding that restates a prior one belongs to that finding's grade, never to this list.

### 5. Report

Print, in order:

1. `## Prior findings`: each as `path:line`, its grade, and one line on what remains when it is not **Fixed**.
2. `## New findings`: under `### Standards` and `### Spec`, as `/code-review` reports them.

End with one line: counts of **Fixed**, **Partial**, and **Open**, then the count of new findings per axis.

The **Partial**, **Open**, and new findings form the set a later `/post-pr-review` posts.
