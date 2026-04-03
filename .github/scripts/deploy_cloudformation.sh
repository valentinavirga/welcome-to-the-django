#!/usr/bin/env bash
set -euo pipefail

REGION="${AWS_REGION}"
STACK_NAME="${CF_STACK_NAME:-welcome-to-the-django-prod}"
BUCKET_NAME="${CF_BUCKET_NAME}"
DEPLOY_ROLE_ARN="${CF_DEPLOY_ROLE_ARN:-}"
PARAM_FILE="infra/parameters/prod.json"

mapfile -t PARAM_OVERRIDES < <(
  jq -r '.Parameters | to_entries[] | "\(.key)=\(.value|tostring)"' "${PARAM_FILE}"
)

if [[ -n "${BUCKET_NAME}" ]]; then
  FILTERED=()
  for p in "${PARAM_OVERRIDES[@]}"; do
    if [[ "${p}" != BucketName=* ]]; then
      FILTERED+=("${p}")
    fi
  done
  PARAM_OVERRIDES=("${FILTERED[@]}" "BucketName=${BUCKET_NAME}")
fi

set +e
DEPLOY_ARGS=(
  --region "${REGION}"
  --template-file "infra/cloudformation/template.yml"
  --stack-name "${STACK_NAME}"
  --parameter-overrides "${PARAM_OVERRIDES[@]}"
  --capabilities CAPABILITY_NAMED_IAM
)

if [[ -n "${DEPLOY_ROLE_ARN}" ]]; then
  DEPLOY_ARGS+=(--role-arn "${DEPLOY_ROLE_ARN}")
fi

aws cloudformation deploy "${DEPLOY_ARGS[@]}"
DEPLOY_EXIT=$?
set -e

if [[ ${DEPLOY_EXIT} -ne 0 ]]; then
  echo "Deploy failed. Latest CloudFormation events:"
  aws cloudformation describe-stack-events \
    --region "${REGION}" \
    --stack-name "${STACK_NAME}" \
    --max-items 40 || true
  exit ${DEPLOY_EXIT}
fi
