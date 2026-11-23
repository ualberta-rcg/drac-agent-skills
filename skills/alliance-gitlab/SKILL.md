---
name: alliance-gitlab
description: "Interacting with the Compute Canada GitLab instance (git.computecanada.ca). Covers the required `gitlab@` SSH remote username and fixing `git@` authentication failures."
when_to_use: >
  Trigger when cloning, pushing, adding remotes, or troubleshooting SSH/Git
  authentication against git.computecanada.ca.
---

# Compute Canada GitLab (`git.computecanada.ca`)

`git.computecanada.ca` is a GitLab instance. The one non-obvious trap is the SSH
username.

## SSH remote user

Use `gitlab` as the SSH user, not `git`. The default GitLab SSH host is
`git@...`, which does not work here — it must be `gitlab@...`.

- **Correct remote:** `gitlab@git.computecanada.ca:<group>/<project>.git`
- **Wrong remote:** `git@git.computecanada.ca:<group>/<project>.git`

Set it when adding a remote:

```bash
git remote add origin gitlab@git.computecanada.ca:<group>/<project>.git
```

If a clone was set up with `git@` and auth fails, fix it:

```bash
git remote set-url origin gitlab@git.computecanada.ca:<group>/<project>.git
```
