# Working with GitLab

How a change gets from your Windows machine into `main` – and how to undo it if something
went wrong. All commands are meant for **Git Bash** (comes with Git for Windows).

---

## Principles

- **`main` is the truth.** Argo CD deploys exactly what is on `main`.
- **Nobody pushes to `main` directly.** `main` is protected; every change goes through a
  merge request (MR).
- **Every MR must pass the pipeline** before it can be merged.
- **One MR = one commit on `main`.** MRs are squash-merged with fast-forward, so the history
  stays linear and every change can be reverted on its own.
- **Branches are short-lived.** The source branch is deleted automatically after the merge.
- **No manual changes in the cluster.** Argo CD (self-heal) reverts them anyway. Rollbacks
  are done with `git revert` (see [Rolling back `main`](#8-rolling-back-main)).

```
main ───●──────────●──────────●──────►   (only long-lived branch)
         \        /  \        /
         feat/xyz     fix/abc            (short-lived, deleted after merge)
```

---

## 1. One-time setup

### 1.1 Git identity and settings

Use the name and e-mail address of your GitLab profile – the server rejects pushes from
unknown authors.

```bash
git config --global user.name "<first name> <last name>"
git config --global user.email "<email from your GitLab profile>"
```

Recommended settings:

```bash
git config --global init.defaultBranch main
git config --global credential.helper manager
git config --global pull.ff only
git config --global fetch.prune true
git config --global push.autoSetupRemote true
git config --global rebase.autoStash true
git config --global core.autocrlf false
git config --global core.longpaths true
git config --global merge.conflictStyle zdiff3
git config --global rerere.enabled true
```

| Setting                   | Why                                                              |
|---------------------------|------------------------------------------------------------------|
| `credential.helper manager` | Stores the access token encrypted in the Windows credential store |
| `pull.ff only`            | `git pull` never creates merge commits                           |
| `fetch.prune true`        | Branches deleted on GitLab disappear locally as well             |
| `push.autoSetupRemote true` | First push of a new branch works without `-u origin <branch>`  |
| `core.autocrlf false`     | Line endings are controlled by `.gitattributes` (LF)             |
| `core.longpaths true`     | Avoids the Windows path length limit                             |

Check the result:

```bash
git config --global --list
```

### 1.2 Personal access token

SSH is not available, Git uses HTTPS with a token.

1. GitLab → avatar → **Preferences → Access tokens → Add new token**
2. Scopes: **only** `read_repository` and `write_repository`
3. Expiration: max. 90 days (set a calendar reminder)
4. On the first `git clone` / `git push`, Git asks for credentials:
   username = your GitLab username, password = **the token**.
   The Git Credential Manager remembers it.

Never put the token into the remote URL or into a file.

### 1.3 Clone the repository

```bash
git clone <repository-url>
cd openshift-fdb-lbr
```

### 1.4 Activate hooks and Git LFS (once per clone)

```bash
git config core.hooksPath .githooks
git lfs install
```

- `core.hooksPath` activates the versioned hooks in `.githooks/` (see
  [Local checks](#local-checks-pre-commit-hook)).
- Git LFS handles binary files (`*.jar`, `*.sql` dump). The server rejects binary files that
  are not stored in LFS.

Check:

```bash
git config core.hooksPath     # → .githooks
git lfs ls-files              # lists the LFS files
```

---

## 2. Starting a change

Always start from an up-to-date `main`:

```bash
git switch main
git pull
git switch -c <type>/<short-description>
```

### Branch names

| Prefix      | Use for                                   | Example                     |
|-------------|-------------------------------------------|-----------------------------|
| `feat/`     | New function, new app, new config         | `feat/payments-hpa`         |
| `fix/`      | Repairing something broken                | `fix/cim-probe-path`        |
| `chore/`    | Maintenance, version / image updates      | `chore/fdb-3.0.0-beta6`     |
| `ci/`       | Changes to the pipeline                   | `ci/add-helm-lint`          |
| `docs/`     | Documentation only                        | `docs/rollback`             |
| `refactor/` | Restructuring without changing the cluster | `refactor/values-layout`   |

### Rules

- One topic per branch, keep MRs small.
- Update documentation in the same MR as the change it describes.
- No secrets in Git – passwords belong into the manually created OpenShift secret
  (later: Vault). `values.yaml` only contains placeholders like `<DB_PASSWORD>`.

---

## 3. Add, commit, push

### 3.1 Check locally (optional, recommended)

The same checks as in the pipeline:

```bash
sh scripts/policy.sh
sh scripts/repo-checks.sh
```

### 3.2 Commit

```bash
git status                     # what has changed?
git add -A                     # stage everything (including deletions)
git commit -m "feat: add hpa for payments connector"
```

Commit messages follow [Conventional Commits](https://www.conventionalcommits.org), written in
the **imperative** ("add", not "added"):

```
feat: add hpa for payments connector
fix(cim): correct liveness probe path
chore: bump fdb images to 3.0.0-beta6
docs: describe rollback procedure
```

#### Local checks (pre-commit hook)

On every commit `.githooks/pre-commit` runs automatically. It is silent if everything is
fine and aborts the commit if it finds:

- a commit directly on `main`
- trailing whitespace or merge conflict markers
- key files (`*.key`, `*.pem`, `.env`, …) or a private key in a file
- files larger than 5 MB that are not in Git LFS
- `kind: Secret` outside of Helm templates
- a plain-text password in a YAML file

Fix the reported file and commit again. Only in an emergency: `git commit --no-verify` – the
pipeline runs the same checks anyway.

### 3.3 Push

```bash
git push
```

Git prints a link to create a merge request:

```
remote: To create a merge request for feat/payments-hpa, visit:
remote:   https://<gitlab>/…/-/merge_requests/new?merge_request%5Bsource_branch%5D=feat%2Fpayments-hpa
```

---

## 4. Creating the merge request

1. Open the link from the push output – or in GitLab: **Code → Merge requests → New merge
   request**, source branch = your branch, target branch = `main`.
2. Fill in the form:

| Field               | Value                                                                  |
|---------------------|------------------------------------------------------------------------|
| **Title**           | Conventional commit, e.g. `feat: add hpa for payments connector`. The title becomes the commit message on `main`. |
| **Mark as draft**   | Optional – while you are still working on it. Drafts cannot be merged. |
| **Description**     | Template `Default` → what and why, fill in the checklist               |
| **Assignees**       | *Assign to me*                                                         |
| **Reviewers**       | Optional – a colleague                                                 |
| **Merge options**   | ✅ *Delete source branch* (preselected), *Squash commits* is enforced  |

3. **Create merge request**. The pipeline starts automatically.

---

## 5. Updating the merge request

### More changes

Simply commit and push on the same branch – the MR and the pipeline update automatically:

```bash
git add -A
git commit -m "fix: address review comments"
git push
```

### Title, description, draft

In the MR: **Edit** (top right) – or **Mark as ready** to remove the draft status.

### `main` has moved on

With fast-forward merges, your branch must be based on the latest `main`. The MR then shows
**"Rebase"** – click it, GitLab rebases the branch for you. Afterwards update locally:

```bash
git fetch
git reset --hard origin/<your-branch>    # only if you have no local, unpushed work
```

Or rebase locally:

```bash
git fetch
git rebase origin/main
git push --force-with-lease
```

- Force-pushing is **fine on your own feature branch** after a rebase.
- `--force-with-lease` only overwrites if nobody else pushed in the meantime.
- Force-pushing to `main` is blocked – and that is intended.

### Push rejected: "non-fast-forward"

GitLab has commits that you do not have locally (e.g. after the *Rebase* button or an edit
in the web IDE):

```bash
git pull --rebase
git push
```

---

## 6. The pipeline

### Where to find it

MR → tab **Pipelines** → click the pipeline → click a **job** to see its log.

| Job               | Checks                                                                        |
|-------------------|-------------------------------------------------------------------------------|
| `manifest-policy` | `apps/` and `database/`: no `Secret` outside templates, no `latest` tag, no privileged / hostPath, no plain-text password, images in `values.yaml` only from Artifactory |
| `repo-hygiene`    | Whole repo: no CRLF line endings, hooks executable, no key files, no private keys |

The pipeline runs for every MR and after every merge to `main`. The MR can only be merged
when the pipeline is **green**.

### When a check fails

1. Open the red job and scroll to the end of the log. Every finding starts with `ERROR:` and
   shows the file and line.
2. Fix it locally, commit, push – the pipeline runs again.
3. Reproduce locally before pushing: `sh scripts/policy.sh` / `sh scripts/repo-checks.sh`.

| Message                                         | Fix                                                         |
|-------------------------------------------------|-------------------------------------------------------------|
| `kind: Secret must not be stored in Git`        | Remove the file; create the secret manually in OpenShift     |
| `latest tag is not allowed`                     | Use a fixed image tag                                        |
| `insecure setting`                              | Remove `privileged`, `hostPath`, `hostNetwork`, …            |
| `possible plain-text password`                  | Replace the value with a placeholder `<…>`; real value goes into the secret |
| `image not pulled from Artifactory`             | Use the Artifactory path in `values.yaml`                     |
| `files with CRLF line endings`                  | `git add --renormalize .` and commit                          |
| `hooks without executable bit`                  | `git update-index --chmod=+x .githooks/<hook>` and commit     |
| `Failed to pull image … Bad Credentials`        | `DOCKER_AUTH_CONFIG` (*Settings → CI/CD → Variables*) is wrong or expired |
| `Local file … does not exist` (no job starts)   | Wrong file name in `include:` of `.gitlab-ci.yml`             |

A false alarm on purpose (rare): append `# policy:allow - <reason>` to the line.

### Restarting a job

If a job failed for a temporary reason (runner, network): **↻ Retry** on the job.

---

## 7. Merging to `main`

1. Pipeline green, all threads resolved, draft status removed.
2. Look through **Changes** once more (self-review).
3. Click **Merge** – or **Set to auto-merge**, then GitLab merges as soon as the pipeline is
   green.
4. GitLab squashes the MR into **one commit** on `main` and deletes the source branch.
5. Argo CD picks up the change from `main` (auto-sync) – check the app status in Argo CD.

### Clean up locally

```bash
git switch main
git pull
git branch -D <your-branch>
```

`-D` (capital) is required after a squash merge – Git does not recognise the squash commit as
a merge of the branch, so `-d` refuses.

---

## 8. Rolling back `main`

Something was merged that should not be there. **Never** fix it in the cluster by hand and
**never** force-push `main` – revert the change instead. The revert goes through the same MR
and pipeline.

### 8.1 Via the GitLab web UI (recommended)

1. Open the merged MR → button **Revert**.
2. Choose *Revert in branch: main* and ✅ **Start a new merge request with these changes**.
3. GitLab creates a branch and an MR that undoes exactly this change.
4. Pipeline green → **Merge** → Argo CD deploys the previous state.

### 8.2 Via the command line

Find the commit on `main`:

```bash
git switch main
git pull
git log --oneline -10
```

Create a revert MR:

```bash
git switch -c fix/revert-<topic>
git revert <commit-sha>
git push
```

Then create the MR in GitLab as usual (see [section 4](#4-creating-the-merge-request)).

- Because every MR is exactly one commit on `main`, `git revert` removes the whole MR cleanly.
- Several bad MRs: revert them **newest first**, all in the same branch:
  `git revert <newest-sha> <older-sha>`.

### 8.3 Emergency: the cluster must be fixed *now*

If the pipeline takes too long and production is broken:

1. Argo CD → the app → disable **Auto-Sync**.
2. **History and rollback** → select the last working revision → **Rollback**.
3. Then do the revert in Git as described above.
4. Re-enable Auto-Sync once the revert is merged.

Without step 3, Argo CD would deploy the broken state again as soon as Auto-Sync is back on.

---

## 9. Abandoning a branch

MR → **Close merge request**, then delete the branch:

```bash
git switch main
git push origin --delete <branch>   # on GitLab (if it still exists)
git branch -D <branch>              # locally
```

Or in GitLab: **Code → Branches → 🗑**.

> ⚠️ Closed MRs and their commits stay visible on GitLab. If a **real** secret was ever pushed,
> rotate it immediately.

---

## 10. Publishing new images (manual pipeline)

New FDB images arrive as `.tar` files and are pushed to Artifactory by the job
`publish-image` (`.gitlab/ci/image-build.yml`).

1. Upload the `.tar` file to the Artifactory repository `apps_cbs_cir`.
2. Find the exact image name inside the archive:
   ```bash
   tar -xOf <file>.tar manifest.json      # → "RepoTags":["…"]
   ```
3. Branch `chore/fdb-<version>` → update `TAR_FILE`, `SOURCE_IMAGE`, `TARGET_IMAGE` in the
   `matrix` **and** the image tags in the `values.yaml` files → MR → merge.
   If Argo CD runs with Auto-Sync, disable it for the affected apps first – otherwise it
   deploys tags that do not exist yet.
4. **Build → Pipelines → Run pipeline** → branch **`main`** → **Run pipeline**.
5. All `publish-image` jobs green → log ends with `Pushed …@sha256:…`.
6. Sync the apps in Argo CD (or re-enable Auto-Sync).

`ARTIFACTORY_USERNAME` / `ARTIFACTORY_PASSWORD` are **protected** variables – they only exist
in pipelines on `main`, so the job does not work on feature branches.

---

## 11. Troubleshooting

| Symptom                                                         | Cause / fix                                                     |
|-----------------------------------------------------------------|-----------------------------------------------------------------|
| `cannot spawn .githooks/pre-commit: No such file or directory`  | Hook is empty or has CRLF line endings – first line must be `#!/bin/sh`, file saved as LF |
| `LF will be replaced by CRLF`                                   | `core.autocrlf` is still `true` → `git config --global core.autocrlf false`, then `git add --renormalize .` |
| `untracked working tree files would be overwritten: .githooks/…` | Git LFS recreated its hooks on a branch without `.githooks/` → `rm -rf .githooks`, then switch / pull again |
| `! [rejected] … (non-fast-forward)`                             | GitLab has newer commits → `git pull --rebase`, then `git push`  |
| `fatal: Not possible to fast-forward`                           | Local `main` has commits that GitLab does not have → check with `git log --oneline origin/main..main` before resetting anything |
| `pre-receive hook declined … non-LFS binary files`              | Binary file not in LFS → `git lfs track "*.<ext>"`, `git add --renormalize .`, commit, push |
| `pre-receive hook declined` (other)                             | Read the `remote: GitLab: …` lines above – usually e-mail address or file name rules |
| MR shows *Commits 0*                                            | Nothing pushed yet → `git log --oneline origin/main..HEAD`, then `git push` |
| *Merge blocked: Pipeline must succeed*, but no pipeline         | MR → **Pipelines → Run pipeline**                                |
| PowerShell: `&&` is not a valid statement separator             | Use Git Bash – or run the commands one by one                     |

---

## Cheat sheet

| Task                         | Command                                                          |
|------------------------------|------------------------------------------------------------------|
| New branch                   | `git switch main && git pull && git switch -c <type>/<name>`     |
| Check locally                | `sh scripts/policy.sh && sh scripts/repo-checks.sh`              |
| Commit                       | `git add -A && git commit -m "<type>: <description>"`            |
| Push                         | `git push`                                                       |
| Update branch onto `main`    | `git fetch && git rebase origin/main && git push --force-with-lease` |
| Remote has newer commits     | `git pull --rebase`                                              |
| Clean up after merge         | `git switch main && git pull && git branch -D <branch>`          |
| Revert a merged MR           | MR → **Revert** – or `git revert <sha>` on a new branch          |
| Show all branches            | `git branch -a`                                                  |
| Show what is not pushed yet  | `git log --oneline origin/main..HEAD`                            |
