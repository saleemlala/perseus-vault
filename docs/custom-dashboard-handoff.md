# Custom Dashboard Handoff

Last updated: 2026-07-30

## Start here

1. Open `/Users/saleemlala/Projects/perseus-vault`.
2. Check out `saleem/dashboard-ops-console`.
3. Run `git status --short --branch`; the branch should track
   `origin/saleem/dashboard-ops-console`.
4. Read this file and `docs/custom-dashboard-upgrades.md` before changing or
   replacing the installed binary.
5. Open the live console at `http://127.0.0.1:8767/`.

Baseline commit: `be7a603` (`feat(web): add memory operations dashboard`).

## Current state

The custom dashboard is installed at `~/.local/bin/perseus-vault` and managed by
launchd through:

```text
~/Library/LaunchAgents/com.perseus-vault.web.plist
```

The live service is expected to report:

```bash
curl -fsS http://127.0.0.1:8767/api/health | jq
```

At handoff, it was healthy and ready with semantic recall available and all
`37/37` active memories embedded.

Latest pre-install rollback snapshot:

```text
~/.perseus-vault/backups/custom-dashboard-reviewed-20260730T232248Z
```

The maintained fork is `saleemlala/perseus-vault`, with the official repository
configured as the `upstream` remote.

## What changed

- Replaced the original dashboard with a local, dependency-free operations
  console: Overview, Memories, Activity, Governance, and Relationships.
- Added read-only APIs for health, quality, hygiene, operator review, keystones,
  agents, filtered timeline, history, and aggregate statistics.
- Made dashboard search observational by setting `skip_side_effects`; browsing
  must not alter retrieval counts, access timestamps, decay scores, or layers.
- Added workspace-aware history and timeline filtering.
- Kept unauthenticated loopback mode same-origin by omitting reflective CORS
  headers. Authenticated mode retains bearer-token CORS behavior.
- Removed CDN and `vis-network` dependencies; relationships are text-first.
- Added a health-gated updater with backups, tests, release build, codesigning,
  atomic install, restart, and rollback.

## Code map

- `src/web/dashboard.html`: complete HTML, CSS, and JavaScript console.
- `src/web/mod.rs`: Axum routes, CORS/auth behavior, API handlers, and web tests.
- `src/db.rs`: aggregate queries, scoped history, timeline filters, and counts.
- `src/models.rs`: dashboard statistics and timeline parameter models.
- `src/schema.rs`: API schema additions.
- `src/tools.rs`: timeline argument plumbing.
- `scripts/update-custom-build.sh`: supported upstream update/install path.
- `docs/custom-dashboard-upgrades.md`: update and rollback runbook.

## Invariants

Do not regress these behaviors:

- `/api/search` is read-only and uses `RecallParams.skip_side_effects = true`.
- Dashboard reads never reinforce, decay, promote, or otherwise mutate memories.
- Unauthenticated loopback requests do not reflect arbitrary `Origin` values.
- Dynamic values inserted into HTML attributes use `attr()`, not text-node
  escaping through `esc()`.
- History and timeline can be restricted to an exact workspace. An explicit
  empty workspace selects global rows; an omitted workspace is unscoped.
- `/api/quality` without a category reports global contradiction metrics.
- Timeline responses report the effective clamped offset, not the raw request.
- The updater accepts a healthy empty Vault; `ready=false` alone is not failure.
- No secrets, database contents, encryption keys, or real credentials enter Git.

Focused regression tests for these rules live in `src/web/mod.rs`.

## Validation

Run focused checks while iterating:

```bash
export PATH="$HOME/.cargo/bin:$PATH"
cargo test --locked --no-default-features web:: -- --nocapture
bash -n scripts/update-custom-build.sh
awk '/<script>/{flag=1;next}/<\/script>/{flag=0}flag' \
  src/web/dashboard.html >/tmp/perseus-dashboard.js
node --check /tmp/perseus-dashboard.js
git diff --check
```

Before installing or pushing a release candidate:

```bash
cargo test --locked --no-default-features
cargo build --release --locked
codesign --force --sign - target/release/perseus-vault
codesign --verify --verbose=1 target/release/perseus-vault
```

Baseline result: `511 passed`, `0 failed`, `10 ignored`; the focused web suite
passed `28/28`. Desktop and `390x844` mobile Playwright checks also passed.

## Updating or installing

For normal upstream updates, use only:

```bash
scripts/update-custom-build.sh
```

The script refuses dirty worktrees and `main`, rebases onto `upstream/main`,
validates the build, snapshots the database/key/old binary, installs atomically,
and rolls back if health fails. See `docs/custom-dashboard-upgrades.md` for an
alternate upstream release ref.

Do not run the official installer directly over the custom binary; it can
replace the dashboard build.

## Deferred work

- Persistent time-series snapshots for historical trend charts.
- Recall caller/source attribution.
- Follow/miss outcome instrumentation.
- Richer relationship visualization after the graph has meaningful density.
- Existing pre-fix retrieval and lifecycle counters include historical dashboard
  probing and were intentionally not rewritten.

Current analytics are point-in-time. Do not fabricate historical trends from
present aggregate values.

## Durable memory

Perseus Vault contains the decision memory:

```text
memory_harness/perseus-dashboard-update-guard
mem-f70ebba1a709
```

Recall it before any Perseus Vault upgrade. It records the fork, branch, commit,
updater, recovery path, and the requirement to preserve the custom dashboard.
