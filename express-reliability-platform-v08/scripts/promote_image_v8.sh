#!/bin/bash
###############################################################################
# promote_image_v8.sh — deploy a new image version the GitOps way.
#
# In V7, deploying a new build meant running tf_deploy_v7.sh, which ran
# `helm upgrade` against whatever `:latest` happened to be in ECR at that
# moment. Nothing recorded what got deployed, so "which build is in prod?"
# was answered by SSHing into the cluster and reading a pod spec.
#
# In V8 you do not deploy. You change the desired state and let Argo CD
# deploy: this script rewrites image.tag in gitops/apps/<env>/*.yaml, and
# the commit you make afterwards IS the deployment. `git log gitops/apps/prod`
# is the deploy history, `git revert` is the rollback, and a pull request is
# the change-approval process — no extra tooling required.
#
# Usage:
#   ./scripts/promote_image_v8.sh                    # current HEAD sha -> dev
#   ./scripts/promote_image_v8.sh 4a91c2e prod       # a specific sha -> prod
#   ./scripts/promote_image_v8.sh 4a91c2e prod --commit
#
# Without --commit the files are edited and left for you to review. That is
# the default on purpose: the commit is the deploy, so it should be a
# deliberate act.
###############################################################################
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

REGION="${AWS_REGION:-us-east-1}"
PROJECT="reliability-platform"
SERVICES=(flask-api node-api web-ui)

TAG="${1:-$(git rev-parse --short HEAD)}"
ENV="${2:-dev}"
COMMIT="${3:-}"

case "${ENV}" in
  dev|staging|prod) ;;
  *) echo "ERROR: ENV must be one of dev|staging|prod (got: ${ENV})" >&2; exit 1 ;;
esac

APPS_DIR="gitops/apps/${ENV}"
if [[ ! -d "${APPS_DIR}" ]]; then
  echo "ERROR: ${APPS_DIR} not found — no such environment in gitops/." >&2
  exit 1
fi

if [[ "${TAG}" == "latest" ]]; then
  echo "ERROR: refusing to promote ':latest'." >&2
  echo "       governance/gatekeeper's no-latest-tag constraint denies it at" >&2
  echo "       admission, so this would produce a permanently OutOfSync app." >&2
  exit 1
fi

echo "=== Promoting ${TAG} to ${ENV} ==="
echo

# ── Check the images actually exist in ECR before pointing Git at them ───────
# Argo CD will happily sync a tag that does not exist; you find out from
# ImagePullBackOff several minutes later. A 5-second check beats that.
MISSING=0
if command -v aws >/dev/null 2>&1; then
  for SVC in "${SERVICES[@]}"; do
    if aws ecr describe-images --region "${REGION}" \
        --repository-name "${PROJECT}/${SVC}" \
        --image-ids "imageTag=${TAG}" >/dev/null 2>&1; then
      echo "  ${SVC}: ${TAG} found in ECR"
    else
      echo "  ${SVC}: ${TAG} NOT FOUND in ECR"
      MISSING=$((MISSING + 1))
    fi
  done
else
  echo '  (aws CLI not found — skipping the ECR existence check)'
fi

if [[ "${MISSING}" -gt 0 ]]; then
  echo
  echo "ERROR: ${MISSING} image(s) missing from ECR at tag '${TAG}'." >&2
  echo "       Build and push them first:  ./scripts/build_push_images_v8.sh" >&2
  echo "       Or re-run with a tag that exists." >&2
  exit 1
fi

# ── Rewrite image.tag in every Application for this environment ─────────────
# The parameter block is:
#     - name: image.tag
#       value: <tag>
# so the value to replace is on the line after the name. perl's range
# operator handles that without a YAML parser.
echo
for F in "${APPS_DIR}"/*.yaml; do
  perl -0pi -e "s{(- name: image\.tag\n(\s*)#[^\n]*\n(?:\s*#[^\n]*\n)*\s*value: )\S+}{\${1}${TAG}}g;
                s{(- name: image\.tag\n\s*value: )\S+}{\${1}${TAG}}g" "${F}"
  echo "  updated $(basename "${F}")"
done

echo
echo '=== Diff ==='
git --no-pager diff --stat "${APPS_DIR}" || true
echo
git --no-pager diff "${APPS_DIR}" | grep -E '^[+-].*value:' || echo '  (no change — already at this tag)'

if [[ "${COMMIT}" == "--commit" ]]; then
  echo
  echo '=== Committing (this is the deploy) ==='
  git add "${APPS_DIR}"
  git commit -m "deploy(${ENV}): promote images to ${TAG}"
  echo
  echo 'Now push. Argo CD syncs the pushed commit, not the local one:'
  echo '  git push'
else
  echo
  echo 'Nothing committed. To deploy this, commit and push:'
  echo "  git add ${APPS_DIR}"
  echo "  git commit -m 'deploy(${ENV}): promote images to ${TAG}'"
  echo '  git push'
fi

echo
echo 'Then watch Argo CD pick it up (up to 3 minutes, or force it):'
echo '  kubectl get applications -n argocd -w'
echo '  kubectl -n argocd patch app flask-api --type merge \'
echo '    -p "{\"operation\":{\"sync\":{\"revision\":\"main\"}}}"'
