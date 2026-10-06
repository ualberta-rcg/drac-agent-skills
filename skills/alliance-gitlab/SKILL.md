---
name: gitlab
description: Interacting with the Compute Canada GitLab instance (git.computecanada.ca). Use when cloning, pushing, or otherwise doing git/ssh against git.computecanada.ca, especially when setting up SSH remotes or key-based auth.
Compute Canada GitLab (git.computecanada.ca)
git.computecanada.ca is a GitLab instance. The one non-obvious trap is the SSH
username.
SSH remote user
Use `gitlab` as the SSH user, not `git`. The default GitLab SSH host is
`git@...`, which does not work here — it must be `gitlab@...`.
Correct remote: `gitlab@git.computecanada.ca:<group>/<project>.git`
Wrong remote: `git@git.computecanada.ca:<group>/<project>.git`
Set it when adding a remote:
```
git remote add origin gitlab@git.computecanada.ca:<group>/<project>.git
```
If a clone was set up with `git@` and auth fails, fix it:
```
git remote set-url origin gitlab@git.computecanada.ca:<group>/<project>.git
```
