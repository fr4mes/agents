---
name: re-review
description: Re-review a branch or PR after the author addressed a prior review. Grades each prior finding against the current code and the author's replies, and lists new findings apart. Use when a PR already has reviews from someone other than its author, when the user asks to re-review or check whether review feedback was addressed, or when another skill such as /review-qa hands over a PR with prior reviews.
---

Follow-up review of a branch or PR whose author pushed fixes for an earlier review. It does two jobs and keeps them apart:

- **Verdict**: grade every prior finding against the current code.
- **New findings**: anything the fresh review raises that no prior finding covers.

## Process

### 1. Collect the prior findings and their replies

Read the PR discussion as [`../code-review/PR-DISCUSSION.md`](../code-review/PR-DISCUSSION.md) describes on every re-review, even when a prior review is already in session context. Use that context to identify findings, and fetch the current discussion to read all replies before grading. A prior finding is any review thread, or point in a review body, from a **prior reviewer**: anyone who submitted a review other than the PR author, excluding bots (`author.__typename` is `Bot`). Take resolved threads too: an author can resolve a thread without fixing it.

Attach to each finding every reply that answers it: the later comments in its thread, and review bodies, conversation comments, or the PR description when they name it. Read each reply in full. An **author note** that answers a finding is its **response**. Preserve each response's full body, author, timestamp, and comment URL for the report.

Done when every prior finding sits in one list with its file, its line, the problem it names, and its responses. With no prior findings there is nothing to verify, so tell the user to run `/code-review` instead and stop.

### 2. Run the fresh review against the merge-base

The fixed point is the PR's merge-base, never the commit the last review saw. A diff that only covers the fix commits hides every unfixed finding in code the author left alone, so those findings look fixed.

Resolve the base with `gh pr view <arg> --json baseRefName`, or take the one the user names. Run `/code-review` against it on this PR, so it weighs every author note and reuses the discussion from step 1.

### 3. Grade each prior finding

Read the code at each finding's path at `HEAD` and grade it:

- **Fixed**: the defect is gone.
- **Partial**: the defect is narrower but still present. Name what remains.
- **Open**: the defect is unchanged.
- **Withdrawn**: the defect is unchanged, but the author's response shows it was never one: the finding misread the code, or the spec asks for this behaviour. Quote the part of the response that settles it.

A finding the fresh run did not raise again is still unproven. Reviews vary between runs, so the code is the only evidence. A finding that moved lines keeps its identity; grade it at its new location.

A response is a claim, never evidence. "Fixed in abc123" earns **Fixed** only when the code at `HEAD` shows it. A response that disputes the finding earns **Withdrawn** only when its reasoning holds against the code and the spec. Otherwise the finding stays **Open**, and its line answers the response's argument directly instead of restating the finding. A response that defers the fix to another PR or ticket leaves the finding **Open**; note the reference.

Done when every prior finding carries a grade, every grade other than **Fixed** says what remains, and every finding with a response says how the response weighed in.

### 4. Split out the new findings

A new finding is one from step 2 that no prior finding covers. A step 2 finding that restates a prior one belongs to that finding's grade, never to this list. An **Explained** finding from step 2 stays in its axis's `Explained` list, never in this one.

### 5. Report

Print, in order:

1. `## Prior findings`: each as `path:line`, its grade, and one line on what remains when it is not **Fixed**. Beside every finding, whatever its grade, quote each response in full as a blockquote, in chronological order. Label each with the author, timestamp, and a link to the original comment. Preserve the original wording and Markdown without shortening, paraphrasing, or replacing text with ellipses. Keep the agent's assessment separate from the quoted responses and say how they weighed in; for a **Partial** or **Open** finding, say why it still applies after them. If the author has not replied, say so.
2. `## Author notes`: as `/code-review` reports them, minus the notes already quoted under Prior findings.
3. `## New findings`: under `### Standards` and `### Spec`, as `/code-review` reports them, each with its `Explained` list.

End with one line: counts of **Fixed**, **Partial**, **Open**, and **Withdrawn**, then the count of new and explained findings per axis.

Done when every author note appears in full exactly once, beside its finding or under Author notes, and every prior finding carries its responses or an explicit note that there are none, so the user can decide whether to keep it.

The **Partial**, **Open**, and new findings are candidates for a later `/post-pr-review`. Carry forward the user's decisions about which findings to keep. **Withdrawn** and **Explained** findings stay out of it.
