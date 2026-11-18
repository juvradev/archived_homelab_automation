#!/bin/sh
# Checks Kubernetes / Helm files below apps/ and database/.
# Comment lines and lines containing "policy:allow" are ignored.
fail=0
err() { echo "ERROR: $1"; fail=1; }
hits() { grep -n $3 -E "$1" "$2" | grep -vE '^[0-9]+:[[:space:]]*#' | grep -v 'policy:allow'; }

PW='(password|passwd|pwd)[[:space:]]*:[[:space:]]*["'"'"']?[^[:space:]"'"'"'{<$]'
REGISTRIES='fioneer\.jfrog\.io|ghcr\.io|quay\.io|docker\.io|registry\.redhat\.io'

for f in $(find apps database -type f \( -name '*.yaml' -o -name '*.yml' \)); do

  case "$f" in
    */templates/*) ;;
    *) grep -qE '^kind:[[:space:]]*Secret[[:space:]]*$' "$f" && err "$f: kind: Secret must not be stored in Git" ;;
  esac

  hits 'image:[[:space:]]*[^[:space:]]+:latest|tag:[[:space:]]*"?latest"?' "$f" && err "$f: latest tag is not allowed"

  hits 'privileged:[[:space:]]*true|allowPrivilegeEscalation:[[:space:]]*true|hostNetwork:[[:space:]]*true|hostPID:[[:space:]]*true|hostPath:' "$f" && err "$f: insecure setting"

  hits "$PW" "$f" -i && err "$f: possible plain-text password"

  hits "$REGISTRIES" "$f" | grep -v 'artifactory\.inet\.julius\.de' && err "$f: image not pulled from Artifactory"

done

[ "$fail" -eq 0 ] && echo "policy: all checks passed"
exit $fail

      if git show ":$f" | grep -qiE '(password|passwd|pwd)[[:space:]]*:[[:space:]]*["'"'"']?[^[:space:]"'"'"'{<$]'; then

        case "$f" in
    */templates/*) ;;
    *) hits "$REGISTRIES" "$f" | grep -v 'artifactory\.inet\.julius\.de' && err "$f: image not pulled from Artifactory" ;;
  esac