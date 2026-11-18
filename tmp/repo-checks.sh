#!/bin/sh
# Prueft das gesamte Repository auf typische Fehler.
fail=0
err() { echo "FEHLER: $1"; fail=1; }

# Keine CRLF-Zeilenenden im Repo (ausser .bat/.ps1)
crlf=$(git ls-files --eol | grep 'i/crlf' | grep -vE '\.(bat|ps1)$')
[ -n "$crlf" ] && { echo "$crlf"; err "Dateien mit CRLF im Repo"; }

# Hooks muessen ausfuehrbar sein
nonexec=$(git ls-files -s .githooks | grep -v '^100755')
[ -n "$nonexec" ] && { echo "$nonexec"; err "Hooks ohne Ausfuehrbar-Bit"; }

# Keine Schluesseldateien
keys=$(git ls-files | grep -E '\.(key|pem|p12|pfx|jks|kubeconfig)$|(^|/)\.env$|id_rsa|id_ed25519')
[ -n "$keys" ] && { echo "$keys"; err "Schluesseldateien im Repo"; }

# Kein Private Key im Inhalt
pk=$(git grep -lI "PRIVATE[ ]KEY" -- . ':!.githooks' || true)
[ -n "$pk" ] && { echo "$pk"; err "Private Key im Inhalt"; }

[ "$fail" -eq 0 ] && echo "repo-hygiene: alles ok"
exit $fail