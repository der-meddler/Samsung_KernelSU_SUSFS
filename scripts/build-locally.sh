#!/usr/bin/env bash
# Build the SM-A556B kernel exactly like .github/workflows/a556b.yml does, without GitHub Actions.
# The workflow is the source of truth: the feature steps below are transcriptions of the WildKernels
# composite actions in .github/actions/* resolved for BRANCH=SM-A556B-Oneui7-bitA (6.1/android14),
# and the source/toolchain/build/packaging steps mirror .github/actions/a556b/*. Keep them in sync.
#
#   WS=~/a556b/ws SOURCE_REF=main ./scripts/build-locally.sh
#
# Environment (all optional):
#   WS            workspace root, persistent between runs (toolchain, bazel cache)  [./ws]
#   SOURCE_REPO   GitHub repo of the kernel source                      [der-meddler/A556B-source]
#   SOURCE_REF    branch, tag or commit to build                         [main]
#   LTO           default | thin | full                                  [default]
#   KERNEL_SUFFIX suffix appended to uname -r                            [-Wild]
#   BAZEL_FLAGS   extra bazel build flags                                [--config=local --make_jobs=<n>]
#   KSUN SUSFS NOMOUNT BBG UNICODEFIX DROIDSPACE MACVLAN NTSYNC BBRV3 IPV6_NAT TTL OPTIMIZATION
#                 feature switches, "true"/"false"                       [all true]
#   OUT           where the AnyKernel3 zip and Image are copied          [$WS/dist]
set -euo pipefail

BUILDER=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
WS=${WS:-$PWD/ws}; WS=$(mkdir -p "$WS" && cd "$WS" && pwd)
SOURCE_REPO=${SOURCE_REPO:-der-meddler/A556B-source}
SOURCE_REF=${SOURCE_REF:-main}
LTO=${LTO:-default}
KERNEL_SUFFIX=${KERNEL_SUFFIX--Wild}
OUT=${OUT:-$WS/dist}
for v in KSUN SUSFS NOMOUNT BBG UNICODEFIX DROIDSPACE MACVLAN NTSYNC BBRV3 IPV6_NAT TTL OPTIMIZATION; do
  eval ": \${$v:=true}"
done
JOBS=$(( $(nproc) > 2 ? $(nproc) - 2 : 1 ))
BAZEL_FLAGS=${BAZEL_FLAGS-"--config=local --make_jobs=$JOBS"}

# --- the environment the WildKernels actions expect -------------------------------------------
export BRANCH=SM-A556B-Oneui7-bitA KERNEL_VER=6.1 ANDROID_VER=android14 BUILD_LTO=$LTO
export ROOT=$WS CONFIG=$WS/a556b
export ANYKERNEL3=$WS/AnyKernel3 KERNEL_PATCHES=$WS/kernel_patches
export COMMON=$CONFIG/kernel GKI_DEFCONFIG=$CONFIG/kernel/arch/arm64/configs/gki_defconfig
export GITHUB_WORKSPACE=$BUILDER   # the source/toolchain steps read patches/, workspace/, toolchain/ from here
export GITHUB_ENV=$WS/.env         # variables the steps export, re-read below
: > "$GITHUB_ENV"

step() { printf '\n==== %s  (%s)\n' "$1" "$(date +%H:%M:%S)"; }
cfg() { "$COMMON/scripts/config" --file "$GKI_DEFCONFIG" "$@"; }
reload_env() { set -a; . "$GITHUB_ENV"; set +a; }

# --- dependencies (actions/a556b/dependencies) -------------------------------------------------
step "WildKernels kernel_patches and AnyKernel3"
cd "$WS"
rm -rf kernel_patches AnyKernel3
git clone -q --depth 1 https://github.com/WildKernels/kernel_patches.git
git clone -q --depth 1 -b gki-2.0 https://github.com/WildKernels/AnyKernel3.git

# --- source (actions/a556b/source) --------------------------------------------------------------
step "Kernel source $SOURCE_REPO@$SOURCE_REF"
URL="https://github.com/$SOURCE_REPO.git"; MIRROR="$CONFIG/.source-mirror.git"; KDIR="$CONFIG/kernel"
mkdir -p "$MIRROR"; [ -f "$MIRROR/HEAD" ] || git -C "$MIRROR" init -q --bare
git -C "$MIRROR" fetch -q --depth 1 "$URL" "$SOURCE_REF"
SHA=$(git -C "$MIRROR" rev-parse FETCH_HEAD)
TAG=$(git -C "$MIRROR" ls-remote --tags "$URL" | awk -v s="$SHA" '$1 == s { sub("refs/tags/", "", $2); sub(/\^\{\}$/, "", $2); print $2 }' | head -n1)
[ -n "$TAG" ] || TAG="g${SHA:0:12}"
rm -rf "$KDIR" "$CONFIG/projects"; mkdir -p "$KDIR"
git -C "$MIRROR" archive --format=tar FETCH_HEAD | tar -xf - -C "$KDIR"
mv "$KDIR/projects" "$CONFIG/projects"
cp "$BUILDER/workspace/WORKSPACE" "$CONFIG/WORKSPACE"
export SOURCE_SHA=$SHA SOURCE_TAG=$TAG
echo "source $SHA ($TAG)"
for p in "$BUILDER"/patches/a556b/*.patch; do echo "patch $(basename "$p")"; patch -p1 -d "$KDIR" --no-backup-if-mismatch < "$p"; done
grep -q '^# finally, add the abXXX number if BUILD_NUMBER is set$' "$KDIR/scripts/setlocalversion"
sed -i "s/^# finally, add the abXXX number if BUILD_NUMBER is set\$/&\nBUILD_NUMBER=${SOURCE_TAG}/" "$KDIR/scripts/setlocalversion"

# --- toolchain (actions/a556b/toolchain) --------------------------------------------------------
step "Kleaf toolchain"
MANIFEST="$BUILDER/toolchain/manifest.tsv"; STAMP="$CONFIG/.toolchain-stamp"; WANT=$(sha256sum "$MANIFEST" | cut -c1-64)
if [ -f "$STAMP" ] && [ "$(cat "$STAMP")" = "$WANT" ] && [ -x "$CONFIG/tools/bazel" ]; then
  echo "toolchain already installed"
else
  rm -f "$STAMP"; cd "$CONFIG"
  grep -v '^#' "$MANIFEST" | grep -v '^[[:space:]]*$' | while IFS=$'\t' read -r dest project sha subdir; do
    url="https://android.googlesource.com/${project}/+archive/${sha}"; [ -n "${subdir:-}" ] && url="${url}/${subdir}"; url="${url}.tar.gz"
    echo "-> $dest"; rm -rf "$dest"; mkdir -p "$dest"
    for attempt in 1 2 3 4 5; do
      if curl -fsSL --retry 3 "$url" | tar -xz -C "$dest"; then break; fi
      [ "$attempt" -lt 5 ] || { echo "download of $url failed"; exit 1; }
      echo "retrying ($attempt)"; sleep $((attempt * 15))
    done
  done
  mkdir -p tools; ln -sfn ../build/kernel/kleaf/bazel.sh tools/bazel
  echo "$WANT" > "$STAMP"
fi
cd "$CONFIG"
CLANG_VERSION=$(sed -n 's/^CLANG_VERSION=//p' kernel/build.config.constants)
test -x "prebuilts/clang/host/linux-x86/clang-${CLANG_VERSION}/bin/clang" || { echo "toolchain lacks clang-${CLANG_VERSION}"; exit 1; }
test -x tools/bazel

# --- features, in the workflow's order ---------------------------------------------------------
if [ "$KSUN" = true ]; then
  step "KernelSU-Next (actions/ksun, susfs=$SUSFS)"
  cd "$COMMON"
  if [ "$SUSFS" = true ]; then
    curl -LSs "https://raw.githubusercontent.com/pershoot/KernelSU-Next/dev-susfs/kernel/setup.sh" | bash -s dev-susfs
  else
    curl -LSs "https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/next/kernel/setup.sh" | bash -s dev
    cfg --enable CONFIG_KSU
  fi
  cd "$COMMON/KernelSU-Next"
  git fetch origin dev 2>/dev/null || true
  KSU_GIT_VERSION=$(git rev-list --count refs/remotes/origin/dev 2>/dev/null)
  KSU_GIT_TAG=$(git describe --tags --abbrev=0 refs/remotes/origin/dev 2>/dev/null || echo "")
  KSU_VERSION=$((30000 + KSU_GIT_VERSION))
  sed -i "s/^KSU_VERSION_FALLBACK := 1$/KSU_VERSION_FALLBACK := ${KSU_VERSION}/" kernel/Kbuild
  sed -i "s/^KSU_VERSION_TAG_FALLBACK := v0.0.1$/KSU_VERSION_TAG_FALLBACK := ${KSU_GIT_TAG}/" kernel/Kbuild
  export KSU_VERSION KSU_GIT_TAG
  if [ "$SUSFS" = true ]; then
    sed -i \
      -e 's/^static int security_context_to_sid_with_policy(/int security_context_to_sid_with_policy(/' \
      -e 's/^static int security_sid_to_context_with_policy(/int security_sid_to_context_with_policy(/' \
      -e 's/^static void security_compute_av_user_with_policy(/void security_compute_av_user_with_policy(/' \
      kernel/feature/selinux_hide.c
  fi
  echo "KernelSU-Next $KSU_GIT_TAG ($KSU_VERSION) $(git rev-parse --short HEAD)"
fi

if [ "$KSUN" = true ] && [ "$SUSFS" = true ]; then
  step "SUSFS (actions/susfs-patches)"
  cd "$WS"; rm -rf susfs4ksu
  git clone -q --depth 1 -b "gki-$ANDROID_VER-$KERNEL_VER" --single-branch https://gitlab.com/simonpunk/susfs4ksu.git
  cd susfs4ksu
  git -c user.name=builder -c user.email=builder@localhost fetch -q https://gitlab.com/pershoot/susfs4ksu.git gki-android14-6.1-dev
  git log ..FETCH_HEAD --oneline -n 2 | awk '{print $1}' | tac | xargs -r git -c user.name=builder -c user.email=builder@localhost cherry-pick
  SUSFS4KSU=$WS/susfs4ksu
  cd "$COMMON"
  cp "$SUSFS4KSU/kernel_patches/fs/"* ./fs/
  cp "$SUSFS4KSU/kernel_patches/include/linux/"* ./include/linux/
  cp "$SUSFS4KSU/kernel_patches/50_add_susfs_in_gki-$ANDROID_VER-$KERNEL_VER.patch" ./
  sed -i '/#ifdef CONFIG_SECURITY_DEFEX/,/^#endif/d' fs/open.c
  sed -i '/copy_flags = CL_COPY_UNBINDABLE | CL_EXPIRE;/,/#endif/ {
    /#ifdef CONFIG_KDP_NS/,/#endif/ {
       /#else/,/#endif/!d
       /#else/d
       /#endif/d
    }
   }' fs/namespace.c
  patch -p1 < "50_add_susfs_in_gki-$ANDROID_VER-$KERNEL_VER.patch" || true
  rm -f "50_add_susfs_in_gki-$ANDROID_VER-$KERNEL_VER.patch"
  # kernel_patches/samsung/$BRANCH/*.patch: none exist for SM-A556B
  if grep -q 'VMA_PAD_START(' fs/proc/task_mmu.c && ! grep -qE '#include <linux/pgsize_migration(_inline)?\.h>|define VMA_PAD_START' fs/proc/task_mmu.c; then
    sed -i '1a #ifndef VMA_PAD_START\n#define VMA_PAD_START(vma) ((vma)->vm_end)\n#endif' fs/proc/task_mmu.c
  fi
  if grep -q '__fold_filemap_fixup_entry' fs/proc/task_mmu.c && ! grep -q '#include <linux/page_size_compat.h>' fs/proc/task_mmu.c; then
    sed -i '/#include <linux\/pkeys.h>/a #include <linux/page_size_compat.h>' fs/proc/task_mmu.c
  fi
  cfg --enable CONFIG_KSU_SUSFS
fi

if [ "$KSUN" = true ] && [ "$NOMOUNT" = true ]; then
  step "NoMount (actions/nomount)"
  cd "$COMMON"
  curl -LSs https://raw.githubusercontent.com/maxsteeel/nomount/refs/heads/dev/kernel/setup.sh | bash -
  cfg --enable CONFIG_NOMOUNT
fi

if [ "$BBG" = true ]; then
  step "Baseband Guard (actions/bbg)"
  cd "$COMMON"
  curl -LSs https://github.com/vc-teahouse/Baseband-guard/raw/main/setup.sh | bash
  cfg --enable CONFIG_BBG
  sed -i '/^config LSM$/,/^help$/{ /^[[:space:]]*default/ { /baseband_guard/! s/selinux/selinux,baseband_guard/ } }' security/Kconfig
  sed -i '/^CONFIG_LSM=/ s/"$/,baseband_guard"/' "$GKI_DEFCONFIG"
fi

if [ "$UNICODEFIX" = true ]; then
  step "Unicode fix (actions/unicode)"
  cd "$COMMON"
  patch -p1 < "$KERNEL_PATCHES/common/unicode_bypass_fix_6.1+.patch"
fi

if [ "$DROIDSPACE" = true ]; then
  step "Droidspaces (actions/droidspaces)"
  cd "$COMMON"
  patch -p1 < "$KERNEL_PATCHES/common/droidspaces/fix_sysvipc_kabi_6_7_8.patch"
  for c in SYSVIPC POSIX_MQUEUE IPC_NS PID_NS USER_NS DEVTMPFS NETFILTER_XT_MATCH_ADDRTYPE NETFILTER_XT_TARGET_REJECT \
           NETFILTER_XT_TARGET_LOG NETFILTER_XT_MATCH_RECENT IP_SET IP_SET_HASH_IP IP_SET_HASH_NET NETFILTER_XT_SET; do
    cfg --enable "CONFIG_$c"
  done
  if [ "$MACVLAN" = true ]; then step "MACVLAN (actions/a556b/extras)"; cfg --enable CONFIG_MACVLAN; fi
fi

if [ "$NTSYNC" = true ]; then
  step "ntsync (actions/ntsync)"
  cd "$COMMON"
  patch -p1 < "$KERNEL_PATCHES/common/ntsync/ntsync_base.patch"
  patch -p1 < "$KERNEL_PATCHES/common/ntsync/ntsync_compat_$ANDROID_VER-$KERNEL_VER.patch"
  cfg --enable CONFIG_NTSYNC
fi

if [ "$BBRV3" = true ]; then
  step "BBRv3 (actions/bbrv3)"
  cd "$COMMON"
  patch -p1 < "$KERNEL_PATCHES/common/bbrv3/0001-net-tcp-backport-BBRv3-to-$ANDROID_VER-$KERNEL_VER.patch"
  for c in NET_SCH_FQ NET_SCH_FQ_CODEL NET_SCH_CAKE NET_SCH_PIE NET_SCH_FQ_PIE TCP_CONG_ADVANCED TCP_CONG_BBR TCP_CONG_BBR3 TCP_CONG_CUBIC; do cfg --enable "CONFIG_$c"; done
  for c in TCP_CONG_BIC TCP_CONG_WESTWOOD TCP_CONG_HTCP; do cfg --disable "CONFIG_$c"; done
fi

if [ "$IPV6_NAT" = true ]; then
  step "IP sets and IPv6 NAT (actions/IPv6_NAT)"
  cfg --enable CONFIG_IP_SET
  cfg --set-val CONFIG_IP_SET_MAX 65534
  for c in IP_SET_BITMAP_IP IP_SET_BITMAP_IPMAC IP_SET_BITMAP_PORT IP_SET_HASH_IP IP_SET_HASH_IPMARK IP_SET_HASH_IPPORT \
           IP_SET_HASH_IPPORTIP IP_SET_HASH_IPPORTNET IP_SET_HASH_IPMAC IP_SET_HASH_MAC IP_SET_HASH_NETPORTNET IP_SET_HASH_NET \
           IP_SET_HASH_NETNET IP_SET_HASH_NETPORT IP_SET_HASH_NETIFACE IP_SET_LIST_SET NETFILTER_XT_MATCH_ADDRTYPE NETFILTER_XT_SET \
           IP6_NF_NAT IP6_NF_TARGET_MASQUERADE; do cfg --enable "CONFIG_$c"; done
  cd "$COMMON"
  patch -p1 < "$KERNEL_PATCHES/common/IPv6_NAT_FIX.patch"
fi

if [ "$TTL" = true ]; then
  step "TTL (actions/TTL)"
  for c in IP_NF_TARGET_TTL IP6_NF_TARGET_HL IP6_NF_MATCH_HL; do cfg --enable "CONFIG_$c"; done
fi

if [ "$OPTIMIZATION" = true ]; then
  step "Optimization patches (actions/optimization, SM-A556 path)"
  cd "$COMMON"
  P=$KERNEL_PATCHES/common
  patch -p1 < "$P/optimized_mem_operations.patch"
  patch -p1 < "$P/file_struct_8bytes_align.patch"
  patch -p1 < "$P/reduce_cache_pressure.patch"
  patch -p1 < "$P/mem_opt_prefetch.patch"
  patch -p1 < "$P/Samsung/optimise_memcmp_exynos.patch"
  sed -i 's/pm_wakeup_event(dev, 2 \* MSEC_PER_SEC);/pm_wakeup_event(dev, ktime_to_ms(min) + 1);/' kernel/time/alarmtimer.c
  patch -p1 < "$P/int_sqrt.patch"
  patch -p1 < "$P/reduce_gc_thread_sleep_time.patch"
  patch -p1 < "$P/add_timeout_wakelocks_globally.patch"
  patch -p1 < "$P/f2fs_reduce_congestion.patch"
  patch -p1 < "$P/reduce_freeze_timeout.patch"
  sed -e 's/SYM_FUNC_START_PI(clear_page)/SYM_FUNC_START(__pi_clear_page)/' "$P/clear_page_16bytes_align.patch" | patch -p1
  patch -p1 < "$P/add_limitation_scaling_min_freq.patch"
  patch -p1 < "$P/re_write_limitation_scaling_min_freq.patch"
  patch -p1 < "$P/adjust_cpu_scan_order.patch"
  patch -p1 < "$P/avoid_extra_s2idle_wake_attempts.patch"
  patch -p1 < "$P/disable_cache_hot_buddy.patch"
  patch -p1 < "$P/f2fs_enlarge_min_fsync_blocks.patch"
  patch -p1 < "$P/increase_ext4_default_commit_age.patch"
  patch -p1 < "$P/increase_sk_mem_packets.patch"
  patch -p1 < "$P/reduce_pci_pme_wakeups.patch"
  patch -p1 < "$P/silence_irq_cpu_logspam.patch"
  patch -p1 < "$P/silence_system_logspam.patch"
  patch -p1 < "$P/use_unlikely_wrap_cpufreq.patch"
fi

if [ "$KSUN" = true ]; then
  step "Kernel configuration (actions/configs)"
  for c in OVERLAY_FS TMPFS_XATTR TMPFS_POSIX_ACL KALLSYMS KALLSYMS_ALL KPM; do cfg --enable "CONFIG_$c"; done
  T="$COMMON/arch/arm64/configs/s5e8845-bazel_defconfig"
  for c in UH UH_RKP UH_LKMAUTH UH_LKM_BLOCK RKP RKP_CFP_JOPP RKP_CFP_ROPP RKP_CFP SECURITY_DEFEX PROCA FIVE KDP KDP_NS KNOX_NCM; do
    "$COMMON/scripts/config" --file "$T" --disable "CONFIG_$c"
  done
  sed -i 's/check_defconfig//' "$COMMON/build.config.gki"
fi

step "Kernel name (actions/a556b/kernel-name)"
cd "$COMMON"
if [ -n "$KERNEL_SUFFIX" ]; then sed -i "\$s|echo \"\\\$res\"|echo \"\\\$res${KERNEL_SUFFIX}\"|" scripts/setlocalversion; fi
sed -i 's/-dirty//' scripts/setlocalversion
tail -n 3 scripts/setlocalversion

step "Remove protected exports (actions/abi-export)"
cd "$COMMON"
rm -rf ./android/abi_gki_protected_exports_*
perl -pi -e 's/^\s*"protected_exports_list"\s*:\s*"android\/abi_gki_protected_exports_aarch64",\s*$//;' ./BUILD.bazel

step "LTO (actions/lto): $LTO"
case "$LTO" in
  full) cfg --enable CONFIG_LTO_CLANG; cfg --disable CONFIG_LTO_NONE; cfg --disable CONFIG_LTO_CLANG_THIN; cfg --enable CONFIG_LTO_CLANG_FULL ;;
  thin) cfg --enable CONFIG_LTO_CLANG; cfg --disable CONFIG_LTO_NONE; cfg --disable CONFIG_LTO_CLANG_FULL; cfg --enable CONFIG_LTO_CLANG_THIN ;;
  *) echo "LTO default" ;;
esac

# --- build (actions/a556b/build) --------------------------------------------------------------
step "bazel build //projects/s5e8845:s5e8845_user"
cd "$CONFIG"
BAZEL_LTO=""; case "$LTO" in thin|full) BAZEL_LTO="--lto=$LTO";; esac
set -x
tools/bazel build --nocheck_bzl_visibility --config=stamp --sandbox_debug --verbose_failures --debug_make_verbosity=I \
  $BAZEL_LTO $BAZEL_FLAGS //projects/s5e8845:s5e8845_user
set +x

# --- package (actions/a556b/ak3zip-prep) ------------------------------------------------------
step "AnyKernel3"
KERNEL_IMAGE=""
for f in bazel-bin/projects/s5e8845/s5e8845_user/Image bazel-bin/projects/s5e8845/*/Image; do [ -f "$f" ] && { KERNEL_IMAGE=$f; break; }; done
[ -n "$KERNEL_IMAGE" ] || KERNEL_IMAGE=$(find out/bazel/output_user_root -type f -path '*/bin/projects/s5e8845/*/Image' 2>/dev/null | head -n1 || true)
[ -n "$KERNEL_IMAGE" ] || { echo "no Image produced"; exit 1; }
echo "Image: $KERNEL_IMAGE ($(stat -L -c %s "$KERNEL_IMAGE") bytes)"
cp -L "$KERNEL_IMAGE" "$ANYKERNEL3/Image"
"$COMMON/scripts/extract-ikconfig" "$ANYKERNEL3/Image" > "$WS/ikconfig.txt"
grep -E '^(# )?CONFIG_(UH|RKP|KDP|SECURITY_DEFEX|PROCA|FIVE|LTO_(NONE|CLANG_THIN|CLANG_FULL)|KSU|KSU_SUSFS|NOMOUNT|BBG|NTSYNC|TCP_CONG_BBR3|SYSVIPC|PID_NS|USER_NS|MACVLAN|MODVERSIONS|MODULE_SIG_PROTECT)( |=)' "$WS/ikconfig.txt" || true
for bad in CONFIG_UH CONFIG_RKP CONFIG_KDP CONFIG_SECURITY_DEFEX CONFIG_PROCA CONFIG_FIVE; do
  grep -q "^$bad=y" "$WS/ikconfig.txt" && { echo "$bad still enabled"; exit 1; }
done

NAME="SM-A556B-${SOURCE_TAG}"
[ "$KSUN" = true ] && NAME="$NAME-KSUN${KSU_VERSION:-}"
[ "$KSUN" = true ] && [ "$SUSFS" = true ] && NAME="$NAME-SUSFS"
[ "$KSUN" = true ] && [ "$NOMOUNT" = true ] && NAME="$NAME-NM"
[ "$BBG" = true ] && NAME="$NAME-BBG"
[ "$BBRV3" = true ] && NAME="$NAME-BBRV3"
[ "$DROIDSPACE" = true ] && NAME="$NAME-DS"
[ "$NTSYNC" = true ] && NAME="$NAME-NTS"
[ "$IPV6_NAT" = true ] && NAME="$NAME-IPv6_IP-set"
[ "$TTL" = true ] && NAME="$NAME-TTL"
[ "$UNICODEFIX" = true ] && NAME="$NAME-UF"
case "$LTO" in thin|full) NAME="$NAME-LTO_$LTO";; esac
mkdir -p "$OUT"
rm -f "$OUT/$NAME-AnyKernel3.zip"
(cd "$ANYKERNEL3" && zip -q -r -9 "$OUT/$NAME-AnyKernel3.zip" ./* -x '.git/*')
cp -L "$ANYKERNEL3/Image" "$OUT/$NAME-Image"
cp "$WS/ikconfig.txt" "$OUT/$NAME-ikconfig.txt"
step "done: $OUT/$NAME-AnyKernel3.zip"
ls -la "$OUT"
