#!/bin/sh
# Lokale Pruefungen vor jedem Commit.
# Aktivieren (einmal pro Clone): git config core.hooksPath .githooks
# Notfall-Umgehung:              git commit --no-verify

fail=0
err() { echo "pre-commit: $1"; fail=1; }

# 1. Nie direkt auf main committen
branch=$(git symbolic-ref --short HEAD 2>/dev/null)
if [ "$branch" = "main" ] || [ "$branch" = "master" ]; then
  echo "pre-commit: Nicht auf $branch committen. Erst Branch anlegen: git switch -c feat/<name>"
  exit 1
fi

# 2. Leerzeichen am Zeilenende und Merge-Konfliktmarker
if ! git diff --cached --check; then
  err "Leerzeichen am Zeilenende oder Konfliktmarker (Zeilen siehe oben)"
fi

# 3. Pruefungen pro Datei
set -f
IFS='
'
for f in $(git diff --cached --name-only --diff-filter=ACM); do

  case "$f" in
    *.key|*.pem|*.p12|*.pfx|*.jks|*.kubeconfig|.env|*/.env|*id_rsa*|*id_ed25519*)
      err "$f: Schluessel-/Zugangsdatei gehoert nicht ins Git"
      continue ;;
  esac

  size=$(git cat-file -s ":$f")
  if [ "$size" -gt 5242880 ]; then
    err "$f: groesser als 5 MB, bitte ueber Git LFS tracken"
  fi

  if git show ":$f" | grep -qI "PRIVATE KEY"; then
    err "$f: enthaelt einen Private Key"
  fi

  case "$f" in
    *.yaml|*.yml)
      if git show ":$f" | grep -qE '^kind:[[:space:]]*Secret[[:space:]]*$'; then
        err "$f: kind: Secret, Secrets manuell bzw. ueber Vault anlegen"
      fi
      if git show ":$f" | grep -qiE '(password|passwd|pwd)[[:space:]]*:[[:space:]]*["'"'"']?[^[:space:]"'"'"'{]+'; then
        err "$f: sieht nach einem Passwort im Klartext aus"
      fi
      ;;
  esac
done

if [ "$fail" -ne 0 ]; then
  echo "pre-commit: Commit abgebrochen."
fi
exit $fail