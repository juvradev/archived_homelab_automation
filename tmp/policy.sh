#!/bin/sh
# Prueft Kubernetes-/Helm-Dateien unter apps/ und database/.
fail=0
err() { echo "FEHLER: $1"; fail=1; }

for f in $(find apps database -type f \( -name '*.yaml' -o -name '*.yml' \)); do

  case "$f" in
    */templates/*) ;;
    *) grep -qE '^kind:[[:space:]]*Secret[[:space:]]*$' "$f" && err "$f: kind: Secret gehoert nicht ins Git" ;;
  esac

  grep -nE 'image:[[:space:]]*[^[:space:]]+:latest|tag:[[:space:]]*"?latest"?' "$f" && err "$f: latest-Tag"

  grep -nE 'privileged:[[:space:]]*true|allowPrivilegeEscalation:[[:space:]]*true|hostNetwork:[[:space:]]*true|hostPID:[[:space:]]*true|hostPath:' "$f" && err "$f: unsichere Einstellung"

  grep -niE '(password|passwd|pwd)[[:space:]]*:[[:space:]]*["'"'"']?[^[:space:]"'"'"'{]+' "$f" && err "$f: Passwort im Klartext?"

  grep -nE 'fioneer\.jfrog\.io|ghcr\.io|quay\.io|docker\.io|registry\.redhat\.io' "$f" | grep -v 'artifactory\.inet\.julius\.de' && err "$f: Image nicht aus Artifactory"

done

[ "$fail" -eq 0 ] && echo "policy: alles ok"
exit $fail