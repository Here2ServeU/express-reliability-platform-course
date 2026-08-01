#!/bin/bash
###############################################################################
# gitops_set_repo_v8.sh — point the GitOps manifests at YOUR repo and YOUR ECR.
#
# Argo CD pulls charts from a Git repo over the network. It cannot pull from
# the working copy on your laptop, and it will not read the course repo you
# do not have push access to. So before the first deploy, every repoURL in
# gitops/ has to name a repo you can push to, and every image.repository has
# to name your account's ECR.
#
# This script rewrites both, in place, across gitops/. It edits files — it
# does not commit them. Review the diff and commit yourself: that commit is
# the first thing Argo CD will ever sync.
#
# Usage:
#   ./scripts/gitops_set_repo_v8.sh                       # auto-detect both
#   ./scripts/gitops_set_repo_v8.sh https://github.com/me/my-fork.git
#   ACCOUNT_ID=123456789012 ./scripts/gitops_set_repo_v8.sh
#
# Auto-detection:
#   repo URL   — `git remote get-url origin`, normalized from SSH to HTTPS
#   ECR account — `aws sts get-caller-identity`
#   path prefix — this project's directory within the repo, so the script
#                 works whether you cloned the whole course or split V8 out
#                 into a repo of its own
###############################################################################
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

REGION="${AWS_REGION:-us-east-1}"

# ── Step 1: work out the Git repo URL ────────────────────────────────────────
REPO_URL="${1:-}"
if [[ -z "${REPO_URL}" ]]; then
  REPO_URL="$(git remote get-url origin 2>/dev/null || true)"
  if [[ -z "${REPO_URL}" ]]; then
    echo "ERROR: no repo URL given and no 'origin' remote to detect one from." >&2
    echo "       Usage: ./scripts/gitops_set_repo_v8.sh https://github.com/you/your-fork.git" >&2
    exit 1
  fi
fi

# Argo CD can use SSH remotes, but only with a key mounted into the
# repo-server. HTTPS on a public repo needs no credentials at all, which is
# what the course assumes — so normalize git@host:owner/repo.git to
# https://host/owner/repo.git.
if [[ "${REPO_URL}" == git@* ]]; then
  REPO_URL="https://$(echo "${REPO_URL}" | sed -e 's/^git@//' -e 's/:/\//')"
  echo "note: rewrote SSH remote to HTTPS — ${REPO_URL}"
fi
[[ "${REPO_URL}" == *.git ]] || REPO_URL="${REPO_URL}.git"

# ── Step 2: work out this project's path inside the repo ─────────────────────
# `git rev-parse --show-prefix` prints the current directory relative to the
# repo root: "express-reliability-platform-v08/" in the course repo, empty
# if V8 is its own repo. Argo CD's `path` is relative to the repo root, so
# this prefix has to be prepended to every chart path.
PATH_PREFIX="$(git rev-parse --show-prefix 2>/dev/null || echo '')"
PATH_PREFIX="${PATH_PREFIX%/}"

# ── Step 3: work out the ECR account ─────────────────────────────────────────
ACCOUNT_ID="${ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text 2>/dev/null || true)}"
if [[ -z "${ACCOUNT_ID}" || "${ACCOUNT_ID}" == "None" ]]; then
  echo "WARN: could not read your AWS account ID (is the AWS CLI configured?)."
  echo "      Leaving image.repository placeholders alone — set them by hand,"
  echo "      or re-run with ACCOUNT_ID=<your-account-id>."
  ACCOUNT_ID=""
fi

echo "=== Rewriting gitops/ manifests ==="
echo "  repo URL:    ${REPO_URL}"
echo "  path prefix: ${PATH_PREFIX:-<repo root>}"
echo "  ECR account: ${ACCOUNT_ID:-<unchanged>}"
echo

# ── Step 4: rewrite every manifest under gitops/ ─────────────────────────────
FILES=$(find gitops -name '*.yaml' -type f | sort)

for F in ${FILES}; do
  CHANGED=""

  # repoURL: match whatever is there now, so the script is re-runnable after
  # you move the repo, not just once against the placeholder.
  if grep -q 'repoURL:' "${F}"; then
    perl -pi -e "s{^(\s*repoURL:\s*).*\$}{\${1}${REPO_URL}}" "${F}"
    CHANGED="repoURL"
  fi

  # sourceRepos: the AppProject's allow-list. This is a YAML *list*, not a
  # repoURL key, so it needs its own rule — and it is not optional: if the
  # project still allows only the placeholder repo, Argo CD refuses every
  # Application with "application repo ... is not permitted in project".
  if grep -q 'sourceRepos:' "${F}"; then
    perl -0pi -e "s{(sourceRepos:\n(?:\s*\#[^\n]*\n)*\s*- )\S+}{\${1}${REPO_URL}}" "${F}"
    CHANGED="${CHANGED:+${CHANGED}, }sourceRepos"
  fi

  # path: swap whatever prefix is currently in front of the known chart /
  # apps directories for the detected one.
  if grep -qE '^\s*path:\s' "${F}"; then
    if [[ -n "${PATH_PREFIX}" ]]; then
      perl -pi -e "s{^(\s*path:\s*).*?((?:platform/helm|gitops/apps)/\S+)\$}{\${1}${PATH_PREFIX}/\${2}}" "${F}"
    else
      perl -pi -e "s{^(\s*path:\s*).*?((?:platform/helm|gitops/apps)/\S+)\$}{\${1}\${2}}" "${F}"
    fi
    CHANGED="${CHANGED:+${CHANGED}, }path"
  fi

  # image.repository: only the ECR host changes; the
  # /reliability-platform/<svc> suffix is fixed by bootstrap/ecr.tf.
  if [[ -n "${ACCOUNT_ID}" ]] && grep -q 'dkr.ecr' "${F}"; then
    perl -pi -e "s{[0-9A-Za-z_]+\.dkr\.ecr\.[a-z0-9-]+\.amazonaws\.com}{${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com}g" "${F}"
    CHANGED="${CHANGED:+${CHANGED}, }image.repository"
  fi

  [[ -n "${CHANGED}" ]] && echo "  ${F} — ${CHANGED}"
done

echo
echo "=== Done. Nothing has been committed. ==="
echo
echo "Next:"
echo "  git diff gitops/                      # read what changed"
echo "  git add gitops/ && git commit -m 'gitops: point at my repo and ECR'"
echo "  git push"
echo
echo "Argo CD reads the pushed commit, not your working copy. An uncommitted"
echo "change to gitops/ has no effect on the cluster whatsoever — that is the"
echo "whole idea."
