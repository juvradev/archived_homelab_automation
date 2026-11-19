---

## Branch and commit types

Branch name: `<type>/<short-description>` – merge request title / commit message: `<type>: <description>`

| Type        | Use for                                          | Branch example              | MR title example                          |
|-------------|--------------------------------------------------|-----------------------------|-------------------------------------------|
| `feat`      | New function, new app, new configuration         | `feat/payments-hpa`         | `feat: add hpa for payments connector`    |
| `fix`       | Repairing something broken                       | `fix/cim-probe-path`        | `fix: correct liveness probe path of cim` |
| `chore`     | Maintenance, version and image updates           | `chore/fdb-3.0.0-beta6`     | `chore: bump fdb images to 3.0.0-beta6`   |
| `ci`        | Changes to the pipeline or scripts               | `ci/add-helm-lint`          | `ci: add helm lint job`                   |
| `docs`      | Documentation only                               | `docs/rollback`             | `docs: describe rollback procedure`       |
| `refactor`  | Restructuring without changing the cluster state | `refactor/values-layout`    | `refactor: move image settings to values` |

- Lowercase, words separated by `-`, short and descriptive.
- Write the description in the **imperative** ("add", not "added") – it completes the sentence
  *"This change will …"*.
- An optional scope names the affected area: `fix(cim): …`, `chore(database): …`.
- The merge request title becomes the commit message on `main` (squash merge).