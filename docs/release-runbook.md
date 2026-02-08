# Release Runbook

## 1. Overview

Razorfin uses a three-tier release channel system. Images are built once and promoted by re-tagging rather than rebuilding, ensuring that each channel ships the exact same image digest that was validated in the tier below it.

## 2. Release Channels

| Channel | Update Frequency | Source | Target Audience |
|---------|-----------------|--------|-----------------|
| `testing` | Every push to `main` | Fresh build | Developers and testers |
| `latest` | Daily (10:05 UTC) | Previous day's `testing` | General users |
| `stable` | Weekly (Tuesday 10:05 UTC) | Previous week's `latest` | Users requiring stability |

Each promotion also produces a date-stamped tag for rollback purposes (e.g., `testing.20260208`, `latest.20260208`, `stable.20260208`).

## 3. CI/CD Workflows

| Workflow | File | Purpose |
|----------|------|---------|
| **Build** | `build.yml` | Builds all four variants and pushes to the `testing` tag |
| **Promote** | `promote.yml` | Handles daily and weekly promotion via `skopeo copy` with Cosign signing |
| **Build ISOs** | `build-iso.yml` | Produces monthly ISO builds from the `stable` channel (configurable) |

## 4. Standard Promotion Flow

```
push to main
    |
    v
build.yml: build + push to :testing, :testing.YYYYMMDD, :YYYYMMDD
    |
    v  (daily 10:05 UTC, promote.yml)
:testing  -->  :latest, :latest.YYYYMMDD
    |
    v  (Tuesday 10:05 UTC, promote.yml)
:latest  -->  :stable, :stable.YYYYMMDD
```

On Tuesdays, the stable promotion runs **before** the daily promotion. This ensures that `stable` receives the week-old `latest` image rather than the image just promoted from `testing`.

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

### 11.2 Tuesday Stable Promotion Received Today's Testing Image

This should not occur under normal operation because the stable promotion step is ordered before the daily testing-to-latest step. If it does occur, review the workflow run logs to confirm step ordering, then use a manual rollback to the `stable.YYYYMMDD` tag from the previous week.

### 11.3 Emergency Promote Failed

The emergency promote steps in `build.yml` execute after the standard push step. If the build itself failed, the promote steps are skipped because they depend on `steps.push.outputs`. Resolve the build failure first, then re-dispatch the workflow.

### 11.4 Users Tracking a Legacy Channel Tag

Users who installed their system before the channel system was introduced may still be tracking `:latest` from the previous direct-push configuration. This does not require immediate action, as `:latest` continues to receive daily updates. To migrate a system to `stable`:

```bash
sudo bootc switch ghcr.io/razorfinos-org/razorfin:stable
systemctl reboot
```
