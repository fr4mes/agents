# Reading the PR discussion

One query returns the PR description, every review, every thread with all its replies, and the conversation comments. Follow `pageInfo.endCursor` for every connection with `hasNextPage: true`, including comments within each thread, until all pages have been read. `<owner>` and `<repo>` are the base repo, from `gh repo view --json owner,name`.

```sh
gh api graphql -f query='
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $number) {
        author { login }
        body
        createdAt
        url
        reviews(first: 100) {
          pageInfo { hasNextPage endCursor }
          nodes { author { __typename login } state body submittedAt url }
        }
        reviewThreads(first: 100) {
          pageInfo { hasNextPage endCursor }
          nodes {
            id
            isResolved
            isOutdated
            resolvedBy { login }
            comments(first: 100) {
              pageInfo { hasNextPage endCursor }
              nodes { author { __typename login } body path line originalLine createdAt url }
            }
          }
        }
        comments(first: 100) {
          pageInfo { hasNextPage endCursor }
          nodes { author { __typename login } body createdAt url }
        }
      }
    }
  }' -F owner=<owner> -F repo=<repo> -F number=<number>
```

Skip reviews in state `PENDING`, which only their author can see. A review in state `COMMENTED` with an empty body is the wrapper of its inline threads and adds nothing of its own. A thread's first comment opens it: when a reviewer wrote it, it is that reviewer's finding; when the PR author wrote it, it is an author note on that line.

## Author notes

An **author note** is anything the PR author wrote on the PR: the description, conversation comments, review bodies, and every inline comment, whether it opens a thread on their own code or replies to a reviewer. Empty bodies are not notes.

Keep each note's full body, timestamp, URL, and `path:line` when it is inline, plus the finding it replies to when it sits in a reviewer's thread.
