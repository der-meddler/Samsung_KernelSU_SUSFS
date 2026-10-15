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
| `patches/a556b/` | the small source edits WildKernels carry on their `SM-A556B-Oneui7-bitA` branch (include reorders the SUSFS patch needs) |
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

[![KernelSU](https://img.shields.io/badge/KernelSU-Supported-green)](https://kernelsu.org/)
[![SUSFS](https://img.shields.io/badge/SUSFS-Integrated-orange)](https://gitlab.com/simonpunk/susfs4ksu)

</div>
<div align="center">
## ⚠️ Your warranty is no longer valid!

I am **not responsible** for bricked devices, damaged hardware, or any issues that arise from using this kernel.

**Please** do thorough research and fully understand the features included in this kernel before flashing it!

By flashing this kernel, **YOU** are choosing to make these modifications. If something goes wrong, **do not blame me**!

---

### 🚨 Proceed at your own risk!

---

## 🔧 Available Kernels

| Kernel | Repository | Status |
|--------|------------|--------|
| 🏗️ **GKI** | [GKI_KernelSU_SUSFS](https://github.com/WildKernels/GKI_KernelSU_SUSFS) | ✅ Active |
| 👑 **Sultan** | [Sultan_KernelSU_SUSFS](https://github.com/WildKernels/Sultan_KernelSU_SUSFS) | ✅ Active |
| 📱 **OnePlus** | [OnePlus_KernelSU_SUSFS](https://github.com/WildKernels/OnePlus_KernelSU_SUSFS) | ✅ Active |
| 📱 **Samsung** | [Samsung_KernelSU_SUSFS](https://github.com/WildKernels/Samsung_KernelSU_SUSFS) | ✅ Active |

---

## 🔗 Additional Resources

- 🩹 [Kernel Patches](https://github.com/WildKernels/kernel_patches)
- ⚡ [Kernel Flasher](https://github.com/fatalcoder524/KernelFlasher)

---

## 📋 Installation Instructions

For GKI installation, please follow the official guide:

📖 **[KernelSU Installation Guide](https://kernelsu.org/guide/installation.html)**

---

## ✨ Features

- 🔐 **KernelSU**: A root solution for Android GKI devices that works in kernel mode and grants root permission to userspace applications directly in kernel space
- 🛡️ **SUSFS**: An addon root hiding kernel patches and userspace module for KernelSU

---

| 🔧 **Project** | 👨‍💻 **Developer** | 🔗 **Link** |
|:---------------:|:----------------:|:-----------:|
| **KernelSU** | tiann | [![GitHub](https://img.shields.io/badge/GitHub-tiann-blue?style=flat-square&logo=github)](https://github.com/tiann/KernelSU) |
| **KernelSU-Next** | rifsxd | [![GitHub](https://img.shields.io/badge/GitHub-rifsxd-blue?style=flat-square&logo=github)](https://github.com/KernelSU-Next/KernelSU-Next) |
| **Magic-KSU** | 5ec1cff | [![GitHub](https://img.shields.io/badge/GitHub-5ec1cff-blue?style=flat-square&logo=github)](https://github.com/5ec1cff/KernelSU) |
| **SUSFS** | simonpunk | [![GitLab](https://img.shields.io/badge/GitLab-simonpunk-orange?style=flat-square&logo=gitlab)](https://gitlab.com/simonpunk/susfs4ksu.git) |
| **SUSFS Module** | sidex15 | [![GitHub](https://img.shields.io/badge/GitHub-sidex15-blue?style=flat-square&logo=github)](https://github.com/sidex15) |
| **Sultan Kernels** | kerneltoast | [![GitHub](https://img.shields.io/badge/GitHub-kerneltoast-blue?style=flat-square&logo=github)](https://github.com/kerneltoast) |

🙏 Special thanks to the open-source community for their contributions!

---

## 💬 Support

If you encounter any issues or need help, feel free to:
- 🐛 Open an issue in this repository
- 💬 Reach out to me directly

---

## ⚠️ Disclaimer

Flashing this kernel will void your warranty, and there is always a risk of bricking your device. Please make sure to:
- 💾 Back up your data
- 🧠 Understand the risks before proceeding

**🚨 Proceed at your own risk!**

---

<div align="center">

## 📱 Connect With Us

[![Telegram](https://img.shields.io/badge/Telegram-Jimsterino98-blue?logo=telegram)](https://t.me/Ngadhnjim98)
[![Telegram Group](https://img.shields.io/badge/Telegram-Wild__Kernels-blue?logo=telegram)](https://t.me/WildKernelsTG)

</div>

---

## 🌟 Special Thanks

**These amazing people help make this project possible! ❤️**

| Contributor | Contribution |
|-------------|-------------|
| 🛡️ [simonpunk](https://gitlab.com/simonpunk/susfs4ksu.git) | Created SUSFS! |
| 📦 [sidex15](https://github.com/sidex15) | Created module! |
| 🩹 [backslashxx](https://github.com/backslashxx) | Helped with patches! |
| 🔧 [Teemo](https://github.com/liqideqq) | Helped with patches! |
| 💝 [幕落](https://github.com/MuLuo688) | Donation! |
| 🛡️ [vc-teahouse](https://github.com/vc-teahouse) | Created Baseband-guard (BBG)! |

*If you have contributed and are not listed here, please remind me!* 🙏

---
<div align="center">
## 💝 Donations

Any and all donations are appreciated!

PayPal: [paypal.me/NgadhnjimHoxha](paypal.me/NgadhnjimHoxha)

Wise: [wise.com/pay/me/ngadhnjimh](wise.com/pay/me/ngadhnjimh)

Ko-fi: [https://ko-fi.com/jimsterino98](https://ko-fi.com/jimsterino98)

Buy me a coffee: [buymeacoffee.com/jimsterino98](buymeacoffee.com/jimsterino98)

DM on telegram for crypto donations!

