---
name: review-qa
description: Review every PR whose SUP ticket sits in Jira's QA técnico status, most urgent SLA first, with the ticket as the spec. Runs /code-review on a first review and /re-review when the PR has prior reviews. Takes how many PRs to review at once.
disable-model-invocation: true
---

Batch review of the PRs waiting in the `QA técnico` column of the SUP board at `plibots.atlassian.net`. Each PR gets a `/code-review` whose Spec axis is its Jira ticket.

The run is read-only. It MUST NOT post to GitHub, comment on Jira, or transition a ticket. It MUST NOT call `downloadJiraIssueAttachment` or request the `attachment` field: attachments inflate context and are out of scope. When a ticket references an attachment, the review names it and moves on.

## Process

### 1. Take the batch size

The user passes how many PRs to review at once, as a positive integer. When it is missing or not a positive integer, ask for it before anything else.

Done when the batch size is a positive integer.

### 2. Fetch the queue

Resolve the `cloudId` for `plibots.atlassian.net` with `getAccessibleAtlassianResources`. Run `searchJiraIssuesUsingJql` with:

- `jql`: `project = SUP AND status = "QA técnico"`
- `fields`: `summary`, `status`, and the fields under **Ticket fields**. Nothing else.

Page through every result. Done when every ticket in the status is in hand. An empty queue ends the run: tell the user and stop.

### 3. Order by urgency

Sort the tickets yourself; JQL `ORDER BY` on these SLA fields is not proven. Read each SLA's `ongoingCycle.remainingTime.millis`. A breached SLA is negative, so it sorts first.

1. **QA Tec Time** remaining, least first.
2. **Time to resolution** remaining, least first, to break ties.
3. Issue key, ascending, as the last tie-break.

A ticket with no `ongoingCycle` on an SLA sorts after every ticket that has one on that SLA.

Print the queue as a table: rank, key, summary, both remaining times as their `friendly` values. Then go on without waiting.

### 4. Resolve each ticket's PR

Find the PR URL in the ticket's comments with `listJiraIssueComments`. Developers post it as `PR: https://github.com/Plibots/<repo>/pull/<n>`. When comments hold several distinct PRs, each is reviewed.

When no comment has one but the `development` field reports an open pull request, search GitHub instead:

```sh
gh search prs "<KEY>" --owner Plibots --state open --json url,title
```

Then read each candidate with `gh pr view <url> --json title,headRefName,baseRefName,headRefOid,state`. Skip it when `state` is not `OPEN`. The title and `headRefName` SHOULD both contain the ticket key; flag the PR when either does not, and review it anyway.

When a T3 Code `link_pull_request` tool is available, link every resolved PR to this thread.

Then mark each PR as having **prior reviews** when at least one submitted review comes from someone other than the PR author, bots excluded:

```sh
gh api repos/Plibots/<repo>/pulls/<n>/reviews --paginate \
  --jq '[.[] | select(.state != "PENDING" and .user.type != "Bot")] | map(.user.login)'
```

Compare those logins against the PR author from `gh pr view <url> --json author`.

Done when every ticket has its open PRs, each marked with or without prior reviews, or a reason it has none: no link found, PR closed or merged, or no local clone.

### 5. Review in batches

Take PRs in queue order, the batch size at a time. Start one sub-agent per PR in the batch, all at once, with the brief under **Sub-agent brief**. Wait for the whole batch before starting the next. Without sub-agent support, review the PRs one after another in queue order.

Done when every PR has a report or a stated failure.

### 6. Report

One section per PR, in queue order:

```
## <KEY>: <summary>
QA Tec Time: <friendly> · Time to resolution: <friendly> · <PR url>
```

Under it, `Re-review` or `First review`, then the sub-agent's sections as the skill reported them, plus any title or branch flag from step 4.

Then `## Not reviewed`: each skipped ticket with its reason. End with one line: PRs reviewed, split into first reviews and re-reviews; findings per axis across all of them, counting **Partial** and **Open** prior findings with the new ones; and the ticket with the least QA Tec Time left.

To post a review, the user runs `/post-pr-review` on that PR, which also moves the ticket back to `En desarrollo`.

## Sub-agent brief

Pass the ticket key, the `cloudId`, the PR URL, its `baseRefName`, `headRefOid` and whether it has prior reviews, and these steps:

1. **Spec.** Fetch the ticket with `getJiraIssue`, `fields`: `summary`, `description`, `issuelinks`. Fetch its comments with `listJiraIssueComments`. Never download attachments.
2. **Checkout.** The local clone is `~/plibots/<repo>`. When it is missing, stop and report that. Never touch the clone's working tree; review in a worktree:

   ```sh
   git -C ~/plibots/<repo> fetch origin "+refs/pull/<n>/head:refs/review-qa/pr-<n>" "<baseRefName>"
   git -C ~/plibots/<repo> worktree add --detach /tmp/review-qa/<repo>-<n> refs/review-qa/pr-<n>
   ```

   The worktree's `HEAD` MUST equal `headRefOid`. A mismatch means the PR moved; report it and stop.
3. **Review.** In the worktree, with the ticket from step 1 as the spec, so `docs/agents/issue-tracker.md` is not needed:
   - **No prior reviews**: run `/code-review` with the fixed point `git merge-base HEAD origin/<baseRefName>`.
   - **Prior reviews**: run `/re-review` on the PR URL. It grades every prior finding against the current code and the author's replies, then reviews against the merge-base.
4. **Clean up**, whether the review succeeded or not:

   ```sh
   git -C ~/plibots/<repo> worktree remove --force /tmp/review-qa/<repo>-<n>
   git -C ~/plibots/<repo> update-ref -d refs/review-qa/pr-<n>
   ```

5. **Return** what the skill reported: `## Standards` and `## Spec` from `/code-review`, or `## Prior findings` and `## New findings` from `/re-review`. Nothing else.

## Ticket fields

Custom field IDs on `plibots.atlassian.net`. When one is missing from a response, find it by display name in the ticket's `customFields` and tell the user the ID changed.

| Field | ID | Use |
|---|---|---|
| QA Tec Time | `customfield_10561` | SLA, first priority |
| Time to resolution | `customfield_10050` | SLA, second priority |
| development | `customfield_10000` | String summary of the Development panel; says whether a PR exists, never its URL |
