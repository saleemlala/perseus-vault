# Custom Dashboard Upgrade Path

This fork contains the local operations dashboard and its read-only web APIs.
The official Perseus installer must not be run directly after this fork is
installed: it can replace `~/.local/bin/perseus-vault` with the upstream binary.

## Normal upgrade

From this repository:

```bash
scripts/update-custom-build.sh
```

The updater:

1. Requires a clean custom branch, never `main`.
2. Fetches `upstream/main` and rebases the dashboard commit series.
3. Runs the no-default-features test suite.
4. Builds the normal release with semantic embedding support.
5. Ad-hoc codesigns the Apple Silicon binary.
6. Creates an encrypted database, key, and previous-binary rollback snapshot.
7. Atomically installs the binary and restarts the launchd web service.
8. Requires `/api/health` to report `status=healthy`; an intentionally empty Vault is valid.
9. Restores the previous binary and restarts the service if the health check fails.

A different upstream ref can be selected when testing a release:

```bash
PERSEUS_UPSTREAM_REF=upstream/v2.23.0 scripts/update-custom-build.sh
```

The updater does not mutate the Vault database except for the SQLite backup
operation, and it never writes the encryption key into the repository.

## Contribution path

Keep dashboard work in small commits that can be submitted upstream:

- non-mutating dashboard search and route correctness
- read-only operational APIs
- dashboard UI and accessibility
- focused web tests

When upstream accepts a change, the next rebase naturally drops that local
commit. Until then, the fork and updater preserve the work across releases.
