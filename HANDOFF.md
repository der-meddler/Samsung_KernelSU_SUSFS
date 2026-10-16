# A556B kernel project — handoff / resume notes (written 2026-10-16 ~01:10 CEST)

Read this (and the memory files) before continuing. Everything below is already pushed or on disk.

## Done
- **A556B-source** (github.com/der-meddler/A556B-source, local `~/Documents/A556B-A`): Samsung 6.1.93 tree
  at repo root + `projects/`, tags A556BXXU7BYDB → S8BYE1 → S9BYF3 → SABYG2 → SABYI1 (= main). Verified byte-identical
  to the drop in `~/Documents/SM-A556B/` except the 16 hotfix files. Leftover repo A556B-A on GitHub was deleted.
- **Builder** = fork `der-meddler/Samsung_KernelSU_SUSFS`, local `~/Documents/A556B-builder` (remotes origin + upstream=WildKernels).
  Branch `main` mirrors upstream; **branch `a556b` is ours** (pushed: 8fdf56a, 0464356). Layout in README.md top section.
  Workflow `.github/workflows/a556b.yml` (dispatch: source_ref, runner github|local, features, lto, release_type).
  Upstream files untouched → `git merge upstream/main` is conflict-free. Sync automations: sync-upstream.yml
  (needs secret FORK_SYNC_TOKEN: fine-grained PAT, this repo, Contents+Workflows write), sync-wildkernels-patches.yml.
- **Test build PASSED** 2026-10-16 01:27 in the Droidspaces arch container (user `claude`): bazel 19.5 min, Image 38.3 MB,
  release `6.1.93-android14-11-abA556BXXSABYI1-Wild`, no rejected hunks, all features in the embedded config.
  Artifacts copied to `~/Documents/A556B-builder/dist/` (gitignored). Container details:
  `ssh -i ~/.ssh/container_claude -o IdentitiesOnly=yes -p 2222 claude@127.0.0.1` → `~/a556b/build.log`,
  exit code in `~/a556b/build.status` when finished, outputs in `~/a556b/ws/dist/`. Script: `builder/scripts/build-locally.sh`
  (WS=~/a556b/ws). Workspace `~/a556b/ws/a556b/` keeps the toolchain + bazel cache for reruns.

## Next steps
1. (done) local test build passed; rerun any time with `git -C ~/a556b/builder pull && WS=~/a556b/ws bash ~/a556b/builder/scripts/build-locally.sh`.
2. (done) `gh repo edit der-meddler/Samsung_KernelSU_SUSFS --default-branch a556b` (Run-workflow button needs it),
   `gh workflow disable main.yml -R der-meddler/Samsung_KernelSU_SUSFS` (upstream's 63-device matrix).
3. User (root in container): install the widened runner gate from `.github/runner/job-started-gate.sh`
   (reinstall command in its header) so `runner=local` works; then dispatch a556b.yml with runner=local.
4. (done) hosted run 38824206450 passed on 2026-10-16 (34 min, ubuntu-latest): a556b is the default branch, upstream main.yml disabled; artifacts SM-A556B-A556BXXSABYI1-KSUN33383-...-AnyKernel3 + -Image to validate the hosted path (free-disk + 25 GB swap, ~25-40 min).
5. Flash the `*-AnyKernel3.zip` on the A55 (KernelSU-Next manager / recovery); verify Wi-Fi/BT, KSU, SUSFS,
   NoMount, Droidspaces (keep SUSFS "hide sus mounts for all processes" OFF).
6. Later phases: droidspaces fine-tuning, super.img, maybe TWRP (see memory a55x-twrp-research in the A137F memory dir).

## Facts worth remembering
- Bazel target `//projects/s5e8845:s5e8845_user` only (not `_dist`); Image at `bazel-bin/projects/s5e8845/s5e8845_user/Image`.
- Local runs: `--config=local --make_jobs=6` (no user namespaces in the container). Host: 8 cores, 15 GB RAM.
- Toolchain pinned in `toolchain/manifest.tsv` (gitiles tarballs, clang-r487747c). WildKernels' A556B branch kernel == our
  SABYI1 + 3 include patches (in `patches/a556b`) + BUILD_NUMBER (generated from the source tag).
- User preferences: keep agent usage minimal (no fleets), open-source tools, zsh Bash-tool quirks (see memory).

## Roadmap (user, 2026-10-16)
1. KSU LKM mode (experimental), 2. KPM for KPatch-Next (APatch-based) modules, 3. Samsung securities already off
(keep KNOX on), 4. analyse/fix Lyinceer's TWRP decryption zip in ~/Documents (breaks Wi-Fi), 5. super.img
modification (EROFS), 6. two TWRP device trees (current One UI 7 firmware, and the Android 16 firmware).
