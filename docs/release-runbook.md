# Release Runbook

## 1. Overview

Razorfin uses a three-tier release channel system. Images are built once and promoted by re-tagging rather than rebuilding, ensuring that each channel ships the exact same image digest that was validated in the tier below it.

## 2. Release Channels

| Channel | Update Frequency | Source | Target Audience |
|---------|-----------------|--------|-----------------|
| `testing` | Every push to `main` + daily (04:40 UTC) if upstream changed | Fresh build | Developers and testers |
| `latest` | Daily (10:05 UTC) | Previous day's `testing` | General users |
| `stable` | Weekly (Tuesday 10:05 UTC) | The `latest.YYYYMMDD` image from at least 7 days earlier | Users requiring stability |

Each promotion also produces a date-stamped tag for rollback purposes (e.g., `testing.20260208`, `latest.20260208`, `stable.20260208`).

## 3. CI/CD Workflows

| Workflow | File | Purpose |
|----------|------|---------|
| **Build** | `build.yml` | Checks for upstream Bazzite and layered-package changes, builds all four variants, and pushes to the `testing` tag |
| **Promote** | `promote.yml` | Handles daily and weekly promotion via `skopeo copy` with Cosign signing |
| **Build ISOs** | `build-iso.yml` | Produces monthly ISO builds from the `stable` channel (configurable), uploads them to Cloudflare R2 (served at download.razorfin.org), and auto-publishes a GitHub release (stable builds only) |

## 4. Standard Promotion Flow

```
push to main ──┐
               ├──> build.yml: check → build + push to :testing, :testing.YYYYMMDD, :YYYYMMDD
schedule ──────┘    (skips build if neither Bazzite nor layered packages changed)
    |
    v  (daily 10:05 UTC, promote.yml)
:testing  -->  :latest, :latest.YYYYMMDD
    |
    v  (Tuesday 10:05 UTC, promote.yml)
:latest.YYYYMMDD (newest dated >= 7 days ago)  -->  :stable, :stable.YYYYMMDD
```

The build workflow runs a **check** job before building. For scheduled runs (daily at 04:40 UTC), it rebuilds if either of these changed since the current `:testing` image:

- **Base image:** the upstream Bazzite `:stable` digest, compared against the `org.opencontainers.image.base.digest` label.
- **Layered packages:** a fingerprint of the packages Razorfin installs on top of Bazzite that Bazzite does not ship (COSMIC from Fedora `updates`, plus Docker CE), compared against the `org.razorfin.layer-packages` label. Without this, COSMIC fixes only reached users when Bazzite happened to publish a new base. Sunshine (lizardbyte/beta COPR) is excluded because its date-based versions change daily.

If neither changed, the build is skipped. Push, pull request, and manual dispatch events always build.

On Tuesdays, `stable` is promoted from the newest `latest.YYYYMMDD` tag dated at least 7 days earlier, which is the image `latest` pointed to a week ago. It is **not** the current `latest`. Builds only happen when something upstream changes, so the current `latest` can be a single day old.

## 5. Image Variants

All promotions apply to every variant in the build matrix:

- `razorfin` (base)
- `razorfin-dx` (developer experience)
- `razorfin-nvidia-open` (NVIDIA open drivers)
- `razorfin-dx-nvidia-open` (developer experience with NVIDIA open drivers)

## 6. Emergency Hotfix Procedure

Use this procedure when a critical fix must reach `latest` or `stable` immediately, bypassing the scheduled promotion cadence.

1. Merge the fix to `main`. This triggers a standard `testing` build.
2. Navigate to **Actions > Build container image > Run workflow**.
3. Set **Target channel** to `latest` or `stable`.
4. Click **Run workflow**.

The workflow performs the following steps:

- Builds the image and pushes it to `testing` as normal.
- Copies the image to `latest` (and `latest.YYYYMMDD`) via `skopeo copy`.
- If `stable` was selected, the promotion cascades: the image is copied to both `latest` and `stable` along with their respective date-stamped tags.
- Each promoted tag reference is signed with Cosign.

Expected duration: approximately 15 minutes (one build cycle).

## 7. Rollback Procedures

### 7.1 Rollback via the Promote Workflow (Recommended)

This method overwrites a channel tag with a known-good date-stamped image across all four variants.

1. Navigate to **Actions > Promote container image > Run workflow**.
2. Set **Source tag** to a known-good date-stamped tag (e.g., `stable.20260201`).
3. Set **Target tag** to the channel to restore (e.g., `stable`).
4. Click **Run workflow**.

The workflow copies the previous image digest back to the channel tag. Users will receive the rollback on their next `bootc upgrade`.

### 7.2 Rollback on a Single Machine

To roll back an individual system to a specific image:

```bash
# Switch to a specific date-stamped image
sudo bootc switch ghcr.io/razorfinos-org/razorfin:stable.20260201

# Alternatively, switch to a different channel
sudo bootc switch ghcr.io/razorfinos-org/razorfin:latest

# Reboot to apply the change
systemctl reboot
```

### 7.3 Rollback to Previous Boot Entry

If the machine retains a previous deployment:

```bash
# List available deployments
sudo bootc status

# Rollback to the previous deployment
sudo bootc rollback
systemctl reboot
```

## 8. Building ISOs from a Specific Channel

ISOs are built from `stable` by default. To build from a different channel:

1. Navigate to **Actions > Build ISOs > Run workflow**.
2. Set **Channel** to `testing`, `latest`, or `stable`.
3. Click **Run workflow**.

The ISO kickstart `%post` script runs `bootc switch` using the tag of the source image. For example, an ISO built from `stable` will configure the installed system to track `:stable` for future updates.

Notes:

- Dispatching with **`channel: stable`** behaves exactly like the monthly scheduled run, **including publishing a `vYYYYMMDD` GitHub release**. This is the procedure for cutting an out-of-cycle ISO release.
- Dispatching with **`testing` or `latest`** skips the release and uploads the ISOs under channel-suffixed filenames (e.g. `razorfin-live-amd64-testing.iso`), so the public stable download URLs are never overwritten by a non-stable build.

## 8.1 Monthly ISO Releases

Stable ISO builds automatically publish a GitHub release:

- **Tag scheme:** `vYYYYMMDD` (UTC date of the build, e.g. `v20260801`), marked as the latest release.
- **Contents:** SHA256 checksum files as release assets; the release body links the ISO downloads on download.razorfin.org and records the exact `stable` image digests the ISOs were built from.
- **Hosting:** the ISOs themselves live on R2, not as release assets. Only the newest stable build is kept, so older releases' checksums will not match the current downloads.
- **Idempotency:** re-running the workflow on the same UTC day deletes and recreates that day's release and tag.
- **Partial failure:** the release job only runs when *both* variant ISO builds succeed. If one leg fails, fix the issue and use **Re-run failed jobs** on the run — the release publishes automatically once both legs are green.
- **Titanoboa pin:** the workflow and the Justfile pin the org fork `RazorfinOS-org/titanoboa` at branch `razorfin/v0.2-pinned-just` (upstream `v0.2`, the last release supporting `hook-post-rootfs`, plus a commit pinning just to 1.50.0 since v0.2's Justfile is incompatible with just 1.54+). Do not bump the pin without migrating `iso_files/configure_iso.sh` to the new container-native ISO contract (#18).

## 9. Seeding Initial Tags

When the channel system is first deployed, only `testing` tags will exist. To seed the remaining channels:

1. Run the **Promote container image** workflow manually with `source_tag: testing` and `target_tag: latest`.
2. Run it again with `source_tag: latest` and `target_tag: stable`.

After the initial seeding, the daily and weekly schedules will maintain all channels automatically.

## 10. Verifying a Release

### 10.1 Listing Tags on GHCR

```bash
# List tags for the base variant
skopeo list-tags docker://ghcr.io/razorfinos-org/razorfin

# Inspect a specific tag to retrieve its digest
skopeo inspect --format '{{.Digest}}' docker://ghcr.io/razorfinos-org/razorfin:stable
```

### 10.2 Verifying the Cosign Signature

```bash
cosign verify --key cosign.pub ghcr.io/razorfinos-org/razorfin:stable
```

### 10.3 Confirming Two Tags Point to the Same Image

```bash
TESTING=$(skopeo inspect --format '{{.Digest}}' docker://ghcr.io/razorfinos-org/razorfin:testing)
LATEST=$(skopeo inspect --format '{{.Digest}}' docker://ghcr.io/razorfinos-org/razorfin:latest)
echo "testing: ${TESTING}"
echo "latest:  ${LATEST}"
[[ "${TESTING}" == "${LATEST}" ]] && echo "MATCH" || echo "MISMATCH"
```

### 10.4 Checking What a Running System Is Tracking

```bash
bootc status
```

## 11. Troubleshooting

### 11.1 Promotion Skipped: Source Tag Not Found

The promote workflow will skip gracefully if the source tag does not exist. This is expected during initial seeding or if a preceding build failed. Review the build workflow logs to determine why the `testing` tag was not pushed.

### 11.2 Tuesday Stable Promotion Skipped or Picked an Unexpected Image

The stable step logs the `latest.YYYYMMDD` tag it picked and the cutoff date. It skips when `stable` already points to that digest, which is normal when nothing new reached `latest` in the preceding week, or when no `latest.YYYYMMDD` tag is old enough. To promote something else, use the manual promotion with an explicit `latest.YYYYMMDD` source tag.

### 11.3 Emergency Promote Failed

The emergency promote steps in `build.yml` execute after the standard push step. If the build itself failed, the promote steps are skipped because they depend on `steps.push.outputs`. Resolve the build failure first, then re-dispatch the workflow.

### 11.4 Scheduled Build Skipped: No Upstream Changes

The build workflow's `check` job compares upstream Bazzite base image digests against the `org.opencontainers.image.base.digest` label, and the layered-package fingerprint against the `org.razorfin.layer-packages` label, on the current `:testing` images. If both match for every variant, the build is skipped. The job log prints the full layered package list it hashed. If that query fails (e.g. a Fedora mirror outage), the job logs a warning and falls back to the base-digest check alone. This is normal and avoids unnecessary rebuilds. To force a rebuild regardless, use **Actions > Build container image > Run workflow** (manual dispatch always builds).

### 11.5 Release Missing After an ISO Run

The release job requires both variant ISO builds to succeed. Open the run, check which matrix leg failed, fix the cause, and use **Re-run failed jobs** — the release job runs automatically once both legs are green. If the run is re-dispatched instead, the same-day tag is replaced (see §8.1 idempotency).

### 11.6 Build Failed: rpmdb Integrity Check

Both `99-cleanup.sh` (inside the build) and the **Verify rpmdb integrity of rechunked image** step run `build_files/shared/verify-rpmdb.sh`, which fails if `rpmdb.sqlite` does not pass SQLite's `quick_check`. This gate exists because `stable.20260825` shipped with a corrupt rpmdb (its Bazzite base was clean), which broke every rpm transaction on it, including the 2026-09-01 ISO build. If the in-build check fails, the corruption came from our build steps. If only the post-rechunk check fails, it came from the rechunker. Do not push or promote the image either way. Re-run first; if it persists, compare against the base image with the same script.

### 11.7 Old Release Checksums Don't Match a Downloaded ISO

Downloads at download.razorfin.org always serve the newest stable build, while release pages are immutable. Verify a download against the checksums of the **newest** release, not an older one.

### 11.8 Users Tracking a Legacy Channel Tag

Users who installed their system before the channel system was introduced may still be tracking `:latest` from the previous direct-push configuration. This does not require immediate action, as `:latest` continues to receive daily updates. To migrate a system to `stable`:

```bash
sudo bootc switch ghcr.io/razorfinos-org/razorfin:stable
systemctl reboot
```
