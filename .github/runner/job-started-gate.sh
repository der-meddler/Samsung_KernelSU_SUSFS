#!/bin/bash
# Job-started hook for the self-hosted runner in the Droidspaces arch container, installed
# root-owned to /etc/github-actions/job-started-gate.sh (drop-in: gate.conf). The runner serves
# two repositories; every job that is not listed below is refused, so an approved fork PR
# workflow can never run on (or tamper with) this machine:
#   der-meddler/A137F-A
#     build-local.yml          a local- tag push, or a manual workflow_dispatch
#     update-submodules.yml    cron or workflow_dispatch; API-only
#     cleanup-artifacts.yml    same
#   der-meddler/Samsung_KernelSU_SUSFS (the A556B builder)
#     a556b.yml                manual workflow_dispatch only (runner=local picks this machine)
# The trust boundary is "anyone with write access to these repos": only they can dispatch, cron
# runs only from main, and GitHub does not let a workflow overwrite the GITHUB_* variables read
# here. What this cannot see is a reusable workflow a listed one might call (GITHUB_WORKFLOW_REF
# names the caller), so none of the listed workflows may ever grow a job-level `uses:`.
# Exiting non-zero fails the job. After editing, reinstall (as bigdihh in the container):
#   gh api 'repos/der-meddler/Samsung_KernelSU_SUSFS/contents/.github/runner/job-started-gate.sh?ref=main' --jq .content \
#     | base64 -d | sudo tee /etc/github-actions/job-started-gate.sh >/dev/null && sudo chmod +x /etc/github-actions/job-started-gate.sh

deny() {
	echo "job-started gate: refusing $GITHUB_EVENT_NAME of $GITHUB_REF ($GITHUB_WORKFLOW_REF) in $GITHUB_REPOSITORY: $1" >&2
	exit 1
}

case "$GITHUB_REPOSITORY" in
	der-meddler/A137F-A|der-meddler/Samsung_KernelSU_SUSFS) ;;
	*) deny "foreign repository" ;;
esac
# only the exact shape <repo>/.github/workflows/<file>@<ref> gets as far as the file name
case "$GITHUB_WORKFLOW_REF" in
	"$GITHUB_REPOSITORY"/.github/workflows/*@*) ;;
	*) deny "malformed workflow ref" ;;
esac
workflow=${GITHUB_WORKFLOW_REF#"$GITHUB_REPOSITORY"/.github/workflows/}
workflow=${workflow%%@*}

case "$GITHUB_REPOSITORY/$workflow" in
	der-meddler/A137F-A/build-local.yml)
		case "$GITHUB_EVENT_NAME" in
			push) case "$GITHUB_REF" in refs/tags/local-*) ;; *) deny "push but not a local- tag" ;; esac ;;
			workflow_dispatch) ;;
			*) deny "event not allowed" ;;
		esac ;;
	der-meddler/A137F-A/update-submodules.yml|der-meddler/A137F-A/cleanup-artifacts.yml)
		case "$GITHUB_EVENT_NAME" in
			schedule|workflow_dispatch) ;;
			*) deny "event not allowed" ;;
		esac ;;
	der-meddler/Samsung_KernelSU_SUSFS/a556b.yml)
		case "$GITHUB_EVENT_NAME" in
			workflow_dispatch) ;;
			*) deny "event not allowed" ;;
		esac ;;
	*) deny "not an allowed workflow" ;;
esac
exit 0
