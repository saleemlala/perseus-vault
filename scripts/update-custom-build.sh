#!/usr/bin/env bash
# Update the maintained Perseus Vault fork without losing dashboard work.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

branch=$(git branch --show-current)
if [[ "$branch" == "main" || -z "$branch" ]]; then
  echo "Refusing to update from main; run this from the custom dashboard branch." >&2
  exit 1
fi
if [[ -n "$(git status --porcelain)" ]]; then
  echo "Working tree is dirty; commit or stash changes before updating." >&2
  exit 1
fi

export PATH="$HOME/.cargo/bin:$PATH"
upstream_ref=${PERSEUS_UPSTREAM_REF:-upstream/main}
target=${PERSEUS_VAULT_BINARY:-$HOME/.local/bin/perseus-vault}
db=${PERSEUS_VAULT_DB:-$HOME/.perseus-vault/data/perseus-vault.db}
key=${PERSEUS_VAULT_KEY:-$HOME/.perseus-vault/secret.key}
backup_root=${PERSEUS_VAULT_BACKUP_DIR:-$HOME/.perseus-vault/backups}
stamp=$(date -u +%Y%m%dT%H%M%SZ)
backup="$backup_root/custom-update-$stamp"
tmp_target="$target.update-$$"
old_target="$backup/perseus-vault.previous"

cleanup() { rm -f "$tmp_target"; }
trap cleanup EXIT

[[ -x "$target" ]] || { echo "Installed binary not found: $target" >&2; exit 1; }
[[ -f "$db" ]] || { echo "Vault database not found: $db" >&2; exit 1; }
[[ -f "$key" ]] || { echo "Vault encryption key not found: $key" >&2; exit 1; }

mkdir -p "$backup"
umask 077
sqlite3 "$db" ".backup '$backup/perseus-vault.db'"
cp "$key" "$backup/secret.key"
cp "$target" "$old_target"
[[ "$(sqlite3 "$backup/perseus-vault.db" 'PRAGMA integrity_check;')" == "ok" ]]

printf 'Fetching upstream and rebasing %s onto %s\n' "$branch" "$upstream_ref"
git fetch upstream --tags
git rebase "$upstream_ref"

cargo test --locked --no-default-features
cargo build --release --locked
codesign --force --sign - target/release/perseus-vault
codesign --verify target/release/perseus-vault

install -m 755 target/release/perseus-vault "$tmp_target"
mv "$tmp_target" "$target"
launchctl kickstart -k "gui/$(id -u)/com.perseus-vault.web"

healthy=false
for _ in $(seq 1 60); do
  if curl -fsS http://127.0.0.1:8767/api/health | jq -e '.status == "healthy"' >/dev/null 2>&1; then
    healthy=true
    break
  fi
  sleep 0.5
done

if [[ "$healthy" != true ]]; then
  echo "New binary failed the dashboard health check; rolling back." >&2
  install -m 755 "$old_target" "$tmp_target"
  mv "$tmp_target" "$target"
  launchctl kickstart -k "gui/$(id -u)/com.perseus-vault.web" || true
  exit 1
fi

printf 'Perseus Vault update installed: %s\n' "$target"
printf 'Database/key/binary rollback snapshot: %s\n' "$backup"
