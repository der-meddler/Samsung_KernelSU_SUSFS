# A556B builder (der-meddler fork)

This fork builds **one** device, the Galaxy A55 5G (SM-A556B, Exynos 1480 / s5e8845,
android14-6.1), from the pristine Samsung source in
[der-meddler/A556B-source](https://github.com/der-meddler/A556B-source) instead of a
`WildKernels/Samsung_Kernels` branch. WildKernels' feature actions are used unchanged;
everything of ours lives in separate files so `git merge upstream/main` stays conflict-free:

| path | purpose |
| --- | --- |
| `.github/workflows/a556b.yml` | the build: *Run workflow* with the source ref, features, LTO and `runner` = `github` or `local` (self-hosted runner in the Droidspaces container) |
| `.github/actions/a556b/source` | materialise the source tree, move `projects/` beside `kernel/`, add `WORKSPACE`, apply `patches/a556b`, pin `BUILD_NUMBER` to the source tag |
| `.github/actions/a556b/toolchain` + `toolchain/manifest.tsv` | the AOSP Kleaf build system and prebuilts (clang-r487747c, build-tools, bazel, jdk11, sysroots) as pinned gitiles tarballs |
| `.github/actions/a556b/{build,ak3zip-prep,...}` | Bazel build of `//projects/s5e8845:s5e8845_user`, AnyKernel3 packaging, naming |
| `patches/a556b/` | the small source edits WildKernels carry on their `SM-A556B-Oneui7` branch (include reorders the SUSFS patch needs) |
| `scripts/build-locally.sh` | the same sequence without Actions, for a shell in the container |
| `.github/workflows/sync-upstream.yml` | daily: fast-forward `main` from WildKernels and merge it into `a556b` (needs the `FORK_SYNC_TOKEN` secret) |
| `.github/workflows/sync-wildkernels-patches.yml` | weekly: regenerate `patches/a556b` from jimsterino's A556B branch and open a PR when it changed |
| `.github/runner/` | job-started gate for the shared self-hosted runner |

Branches: `main` mirrors upstream, `a556b` is ours. Upstream's `main.yml` (the 63-device matrix)
is disabled in this fork. Flash the `*-AnyKernel3.zip` artifact with the KernelSU-Next manager
or a custom recovery; `vendor_boot`, `init_boot`, `vendor_dlkm` and `dtbo` stay stock. Droidspaces
works without PID/CPU limits (those options would change the stock-module ABI), and SUSFS'
"hide sus mounts for all processes" must stay off for containers to boot.

---

<div align="center">

# 🔥 Wild Kernels for Samsung

[![License: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-blue.svg)](LICENSE)
[![Third-Party Notices](https://img.shields.io/badge/notices-THIRD__PARTY_NOTICES-lightgrey.svg)](https://github.com/WildKernels/GKI_KernelSU_SUSFS/blob/main/THIRD_PARTY_NOTICES.md)
[![KernelSU](https://img.shields.io/badge/KernelSU-Supported-green)](https://kernelsu.org/)
[![SUSFS](https://img.shields.io/badge/SUSFS-Integrated-orange)](https://gitlab.com/simonpunk/susfs4ksu)

</div>

> [!CAUTION]
> Wild Kernels is not responsible for bricked devices or damage. By flashing, you assume all risk. Back up your data and understand the risks before flashing.

---

## About

Samsung kernels built on Samsung's open sources from [opensource.samsung.com/main](https://opensource.samsung.com/main), mirrored at [WildKernels/Samsung_Kernels](https://github.com/WildKernels/Samsung_Kernels), with KernelSU and SUSFS for root hiding and detection evasion — per-model branches (OneUI) built from Samsung manifests. Now with multiple root-implementation flavors.

---

## Features

- **KernelSU / KernelSU-Next / ReSukiSU** — root implementations
- **susfs4ksu** — root hiding (incl. Ptrace Leak Fix, Unicode Fix)
- **NoMount / Mountify** — mount metamodules
- **Baseband Guard** — partition protection
- **Networking** — BBR, IPSet
- **TMPFS** — xattr / POSIX ACLs
- **Performance** — incl. NTSync
- **DroidSpaces** — container runtime

> [!TIP]
> Full documentation: [docs/features.md](https://github.com/WildKernels/GKI_KernelSU_SUSFS/blob/main/docs/features.md)

---

## Installation

See **[Installation Guide](https://github.com/WildKernels/GKI_KernelSU_SUSFS/blob/main/docs/installation.md)**.

---

## Supported Devices

Samsung branches are per model + OneUI version (e.g. `SM-S938B-Oneui8.5`, `SM-S928B-Oneui7`). See the matrix in [`.github/workflows/kernel-samsung.yml`](.github/workflows/kernel-samsung.yml) for the full list.

---

## Our Projects

| Device | Repository | Description |
|--------|------------|-------------|
| **Multi** | [GKI_KernelSU_SUSFS](https://github.com/WildKernels/GKI_KernelSU_SUSFS) | Google GKI sources — built to be generic and work across many devices |
| **Pixel** | [Sultan_KernelSU_SUSFS](https://github.com/WildKernels/Sultan_KernelSU_SUSFS) | Custom kernels for specific Pixel devices — built from Sultan sources |
| **Samsung** | [Samsung_KernelSU_SUSFS](https://github.com/WildKernels/Samsung_KernelSU_SUSFS) | Built from Samsung sources and manifest |
| **OnePlus** | [OnePlus_KernelSU_SUSFS](https://github.com/WildKernels/OnePlus_KernelSU_SUSFS) | Built from OnePlus sources and manifest |

---

## Special Thanks

**These amazing people and projects make this possible:**
- **KernelSU** — [tiann](https://github.com/tiann/KernelSU)
- **KernelSU-Next** — [rifsxd](https://github.com/KernelSU-Next/KernelSU-Next)
- **KernelSU-Next SUSFS Fork** — [pershoot](https://github.com/pershoot/KernelSU-Next)
- **SUSFS** — [simonpunk](https://gitlab.com/simonpunk/susfs4ksu)
- **NoMount** — [maxsteeel](https://github.com/maxsteeel/nomount)
- **DroidSpaces-OSS** — [ravindu644](https://github.com/ravindu644/Droidspaces-OSS)
- **Baseband-guard (BBG)** — [vc-teahouse](https://github.com/vc-teahouse/Baseband-guard)
- **Kernel Patches** — [WildKernels/kernel_patches](https://github.com/WildKernels/kernel_patches)
- **AnyKernel3** — [osm0sis](https://github.com/osm0sis/AnyKernel3)

**Contributors to this repository:**
[![Contributors](https://contrib.rocks/image?repo=WildKernels/Samsung_KernelSU_SUSFS)](https://github.com/WildKernels/Samsung_KernelSU_SUSFS/graphs/contributors)
Have an idea or improvement in mind? Contributions are always welcome — feel free to open a pull request or share your thoughts!

---

## Community

<div align="center">

[![Telegram Group](https://img.shields.io/badge/Telegram-%40WildKernelsTG-2CA5E0?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/WildKernelsTG)
[![Telegram DM](https://img.shields.io/badge/Telegram-%40Jimsterino98-26A5E4?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/Jimsterino98)

</div>

Need help? Open an issue in this repository or reach out on Telegram. Please ask in the [WildKernelsTG group](https://t.me/WildKernelsTG) first for general issues.

---

## Donations

> [!IMPORTANT]
> **Kind note:** A donation is truly just a gift — not a payment for support, features, or priority. It doesn't unlock anything extra on our side and doesn't change how we help you; everyone gets the same community support whether you donate or not. Think of it as a kind “thank you” to help keep development going — not a transaction. If you do choose to give, we're genuinely grateful, but please never feel obligated.

- PayPal: [paypal.me/NgadhnjimHoxha](paypal.me/NgadhnjimHoxha)
- Wise: [wise.com/pay/me/ngadhnjimh](wise.com/pay/me/ngadhnjimh)
- Ko-fi: [https://ko-fi.com/jimsterino98](https://ko-fi.com/jimsterino98)
- Buy me a coffee: [buymeacoffee.com/jimsterino98](buymeacoffee.com/jimsterino98)
- Crypto: DM on Telegram for crypto donations!
