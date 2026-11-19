# GitLab settings

All GitLab settings of this project, so the setup can be reproduced or copied to another
project. Self-managed GitLab, **Premium** tier.

Status: ✅ configured · ⬜ open / to be checked

---

## Environment

| Component          | Value                                                                  |
|--------------------|------------------------------------------------------------------------|
| GitLab             | Self-managed, Premium                                                  |
| Runners            | Shared instance runners, no internet access                            |
| Container images   | Artifactory only – public images via the proxy `it-infra_bce-public_cir`, own images in `apps_cbs_cir` |
| Deployment         | Argo CD (web UI only) → 2 OpenShift namespaces (app, database)         |
| Secrets            | Created manually in OpenShift, HashiCorp Vault planned                 |
| Server-side hook   | Set by the GitLab admin: **binary files must be stored in Git LFS**, otherwise the push is rejected |

---

## Account settings (per user)

| Setting                 | Where                                   | Value / why                                                   |
|-------------------------|-----------------------------------------|---------------------------------------------------------------|
| Personal access token   | *Preferences → Access tokens*           | Scopes **only** `read_repository` + `write_repository`, expiry max. 90 days. SSH is not available. |
| Commit e-mail           | *Edit profile → Emails*                 | Local `git config user.email` must be a **verified** address of the GitLab account |
| Notifications           | *Preferences → Notifications*           | Custom: *Failed pipeline* + *Fixed pipeline* only             |

Local Git setup: see [work-with-gitlab.md](work-with-gitlab.md#1-one-time-setup).

---

## Settings → General

### Visibility, project features, permissions

| Setting                         | Value         | Why                                                  | Status |
|---------------------------------|---------------|------------------------------------------------------|--------|
| Project visibility              | **Private**   | "Internal" would be visible to every logged-in user  | ⬜ |
| Forks                           | Only project members                                         | | ⬜ |
| Git Large File Storage (LFS)    | ✅            | Required – `*.jar` and the DB dump are stored in LFS | ✅ |
| CI/CD                           | ✅            | Pipelines                                            | ✅ |
| Wiki, Pages, Packages, Container registry | ❌  | Docs live in `docs/`, images in Artifactory          | ⬜ |

### Merge requests

| Setting                                         | Value                  | Why                                              | Status |
|-------------------------------------------------|------------------------|--------------------------------------------------|--------|
| Merge method                                    | **Fast-forward merge** | Linear history, branch must be up to date with `main` | ⬜ |
| Squash commits when merging                     | **Require**            | One MR = one commit on `main`, clean reverts     | ✅ |
| Enable "Delete source branch" option by default | ✅                     | Branches are removed after merge                 | ✅ |
| Pipelines must succeed                          | ✅                     | Required checks                                  | ✅ |
| Skipped pipelines are considered successful     | ❌                     |                                                  | ⬜ |
| All threads must be resolved                    | ✅                     | Open comments block the merge                    | ⬜ |
| Squash commit message template                  | `%{title}`             | MR title becomes the commit message on `main`    | ⬜ |
| Default description template                    | `Default`              | `.gitlab/merge_request_templates/Default.md`     | ⬜ |

### Merge request approvals

| Setting                                              | Value | Why                                                      | Status |
|------------------------------------------------------|-------|----------------------------------------------------------|--------|
| Required approvals                                   | **0** | You cannot approve your own MR – 1 would lock you out while working alone | ✅ |
| Prevent approval by author                           | ✅    |                                                          | ⬜ |
| Prevent editing approval rules in merge requests     | ✅    |                                                          | ⬜ |
| Remove all approvals when commits are added          | ✅    |                                                          | ⬜ |

### Badges

| Name     | Link                                                    | Badge image                                                         | Status |
|----------|---------------------------------------------------------|---------------------------------------------------------------------|--------|
| pipeline | `%{gitlab_server}/%{project_path}/-/pipelines`          | `%{gitlab_server}/%{project_path}/badges/%{default_branch}/pipeline.svg` | ⬜ |

---

## Settings → Repository

### Branch defaults

| Setting         | Value  | Status |
|-----------------|--------|--------|
| Default branch  | `main` | ✅ |

### Protected branches

| Branch | Allowed to merge | Allowed to push and merge | Allowed to force push | Code owner approval | Status |
|--------|------------------|---------------------------|-----------------------|---------------------|--------|
| `main` | Maintainers      | **No one**                | ❌                    | ✅ (once `CODEOWNERS` exists) | ✅ |

Nobody – including maintainers – can push to `main` directly. Every change goes through a
merge request.

### Protected tags

| Tag            | Allowed to create | Status |
|----------------|-------------------|--------|
| `fdb-*`        | Maintainers       | ⬜ |
| `postgresql-*` | Maintainers       | ⬜ |

Protected tags cannot be moved or deleted by developers. A tag always marks a deployed state –
see [README – Releases](../README.md#releases).

### Push rules

| Rule                                          | Value                                                     | Status |
|-----------------------------------------------|-----------------------------------------------------------|--------|
| Branch name                                   | `^(feat\|fix\|chore\|ci\|docs\|refactor)\/[a-z0-9._-]+$`  | ⬜ |
| Prevent pushing secret files                  | ✅                                                        | ⬜ |
| Check whether the commit author is a GitLab user | ✅                                                     | ⬜ |
| Reject unsigned commits                       | ❌ – commit signing is not available                      | – |

### Deploy tokens

| Name         | Scopes            | Expiry   | Used by                              | Status |
|--------------|-------------------|----------|--------------------------------------|--------|
| `argocd-dev` | `read_repository` | ⬜ date  | Argo CD repository connection        | ⬜ |

Set a calendar reminder before the expiry date – Argo CD can no longer sync once the token
has expired.

---

## Settings → CI/CD

### General pipelines

| Setting                       | Value  | Status |
|-------------------------------|--------|--------|
| Public pipelines              | ❌     | ⬜ |
| Auto-cancel redundant pipelines | ✅   | ⬜ |
| Timeout                       | 30 min | ⬜ |

### Variables

| Variable               | Protected | Masked + hidden | Used by                                  | Notes |
|------------------------|-----------|-----------------|------------------------------------------|-------|
| `DOCKER_AUTH_CONFIG`   | ❌        | ✅              | Runner – pulls job images from Artifactory in **every** pipeline | Must stay unprotected, otherwise MR pipelines fail. Should contain a **read-only** token only. |
| `ARTIFACTORY_USERNAME` | ✅        | –               | `publish-image` (only on `main`)         | Technical user with write access to `apps_cbs_cir` |
| `ARTIFACTORY_PASSWORD` | ✅        | ✅              | `publish-image` (only on `main`)         | Prefer an Artifactory access token over a password |
| `DB_PASSWORD`          | ✅        | ✅              | ⬜ unclear – delete if no job uses it     | |

| Setting                                   | Value              | Why                                              | Status |
|-------------------------------------------|--------------------|--------------------------------------------------|--------|
| Minimum role to use pipeline variables    | **No one allowed** | Nobody can override variables when starting a pipeline | ⬜ |

Protected variables only exist in pipelines on protected branches (`main`) and protected tags.
A feature branch – and therefore a modified `.gitlab-ci.yml` on a feature branch – never sees
them.

### Job token permissions

| Setting                      | Value                 | Status |
|------------------------------|-----------------------|--------|
| Authorized groups and projects | This project only   | ⬜ |

---

## Pipeline overview

Defined in `.gitlab-ci.yml` (+ `.gitlab/ci/*.yml`):

| Pipeline source               | Jobs                                   |
|-------------------------------|----------------------------------------|
| Merge request                 | `manifest-policy`, `repo-hygiene`      |
| Push to `main` (after merge)  | `manifest-policy`, `repo-hygiene`      |
| *Run pipeline* on `main`      | validate jobs, then `publish-image` (9 images) |
| Push to a branch without MR, tags | no pipeline                        |

Details: [work-with-gitlab.md – The pipeline](work-with-gitlab.md#6-the-pipeline).

---

## Open items

| Item                                                                 | Why                                                     |
|----------------------------------------------------------------------|---------------------------------------------------------|
| `publish-image` uses `curl -k` / `--tls-verify=false`                | Artifactory certificate is not verified                 |
| Separate **read-only** token for `DOCKER_AUTH_CONFIG`                | The variable is readable by every branch pipeline       |
| `CODEOWNERS` for `/.gitlab-ci.yml`, `/.gitlab/`, `/scripts/`, `/.githooks/`, `/database/` | Prevents a branch from weakening the pipeline checks |
| Check images in Artifactory for `yamllint`, `helm`, `gitleaks`       | Real YAML / Helm / secret scanning in the pipeline      |
| Secrets via HashiCorp Vault                                          | Replace manually created OpenShift secrets              |

---

## Lessons from the initial setup

| Situation                                              | What happened / fix                                                        |
|--------------------------------------------------------|----------------------------------------------------------------------------|
| Moved `*.jar` files were rejected on push              | Server-side hook requires binaries in LFS → `git lfs track "*.jar"`, `git add --renormalize .` |
| `Bad Credentials` when pulling job images              | `DOCKER_AUTH_CONFIG` was wrong – the runner needs it to pull images, independent of job variables |
| *Merge blocked: Pipeline must succeed* without a pipeline | *Pipelines must succeed* was already enabled → MR → **Pipelines → Run pipeline** |
| Git LFS created hooks in `.githooks/`                  | `core.hooksPath` points there – the LFS hooks are committed and must stay executable |
| `LF will be replaced by CRLF` for every file           | Git for Windows sets `core.autocrlf=true` → set to `false`, line endings via `.gitattributes` |
| Placeholders in `values.yaml` flagged as passwords     | Policy ignores values starting with `<` or `$`                              |
