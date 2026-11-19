# openshift-fdb-lbr

Deployment configuration for **FDB** (8 microservices) and its **PostgreSQL** database on
OpenShift. Argo CD deploys everything from the `main` branch – if it is not on `main`, it is
not in the cluster.

---

## Current versions

| Component                | Version         | Since tag          |
|--------------------------|-----------------|--------------------|
| FDB                      | `3.0.0-beta5`   | `fdb-3.0.0-beta5`  |
| PostgreSQL               | `18.6`          | `postgresql-18.6`  |

<details>
<summary>Image tags per service</summary>

| Service                  | Chart                          | Image tag                        |
|--------------------------|--------------------------------|----------------------------------|
| alerts-connector         | `apps/fdb-alerts-connector`    | `3.0.0-beta5-202609250918`       |
| banking-connector        | `apps/fdb-banking-connector`   | `3.0.0-beta5-202609250918`       |
| cim                      | `apps/fdb-cim`                 | `3.0.0-beta5-202609280628`       |
| cim-ui                   | `apps/fdb-cim-ui`              | `3.0.0-beta5-202609250458`       |
| corp-ui                  | `apps/fdb-corporate-ui`        | `3.0.0-beta5-202609250458`       |
| payments-connector       | `apps/fdb-payments-connector`  | `3.0.0-beta5-202609250918`       |
| platform                 | `apps/fdb-platform`            | `3.0.0-beta5-202609280505`       |
| retail-ui                | `apps/fdb-retail-ui`           | `3.0.0-beta5-202609250458`       |
| PostgreSQL               | `database`                     | `18.6`                           |

All images are pulled from `artifactory.inet.julius.de/apps_cbs_cir`.

</details>

> Update this table in the **same merge request** that changes the versions.

---

## How it works

```
feature branch ──push──► merge request ──pipeline──► main ──► Argo CD ──► OpenShift
                                                      │
                                    Run pipeline ─────┴──► new images to Artifactory
```

- `main` is protected – changes only via merge request, squash-merged.
- Every merge request must pass the pipeline (`manifest-policy`, `repo-hygiene`).
- Argo CD deploys `apps/` to the app namespace and `database/` to the DB namespace.
- New FDB / PostgreSQL images are published with a manual pipeline on `main`.

---

## Repository structure

```
apps/            Helm charts – one per FDB service (+ fdb-general: DB connection config)
database/        Helm chart – PostgreSQL
tools/           DB encryption tool and migrations (not deployed by Argo CD)
manual/          Manually applied manifests, versioned for reference (e.g. MetalLB)
scripts/         Checks used by the pipeline and locally
.gitlab/ci/      Pipeline jobs (validate, image publish)
.githooks/       Local Git hooks (pre-commit checks, Git LFS)
docs/            Documentation
```

---

## Quick start

Requirements: **Git for Windows** (includes Git Bash and Git LFS).

```bash
git clone <repository-url>
cd openshift-fdb-lbr
git config core.hooksPath .githooks
git lfs install
```

Daily workflow:

```bash
git switch main && git pull && git switch -c feat/<name>
# … change files …
sh scripts/policy.sh && sh scripts/repo-checks.sh
git add -A && git commit -m "feat: <description>"
git push
```

Then create the merge request in GitLab using the link printed by `git push`.

---

## Secrets

Secrets are **never** stored in Git. `values.yaml` only contains placeholders like
`<DB_PASSWORD>`. The real values live in OpenShift secrets that are created manually
(HashiCorp Vault is planned).

---

## Releases

Every delivered version gets a tag on `main` **after** it has been deployed successfully:

| Tag                  | Meaning                         |
|----------------------|---------------------------------|
| `fdb-<version>`      | New FDB version deployed         |
| `postgresql-<version>` | New PostgreSQL version deployed |

Overview: **Code → Tags**.

---

## Documentation

| Document                                          | Content                                                 |
|---------------------------------------------------|---------------------------------------------------------|
| [docs/work-with-gitlab.md](docs/work-with-gitlab.md) | Setup, branches, merge requests, pipeline, rollback, image publishing |
| [docs/work-with-argocd.md](docs/work-with-argocd.md) | Argo CD applications, sync and rollback               |
| [docs/gitlab-settings.md](docs/gitlab-settings.md)   | Project settings (protected branches, variables, …)   |
