#!/usr/bin/env bash
set -euo pipefail

export AWS_PAGER=""

REGION="${AWS_REGION}"
STACK_NAME="${CF_STACK_NAME:-welcome-to-the-django-prod}"
DEPLOY_ROLE_ARN="${CF_DEPLOY_ROLE_ARN:-}"
PARAM_FILE="infra/parameters/prod.json"

if [[ -z "${DEPLOY_ROLE_ARN}" ]]; then
  echo "CF_DEPLOY_ROLE_ARN is required. Set it in GitHub Actions secrets."
  exit 1
fi

if [[ ! "${DEPLOY_ROLE_ARN}" =~ ^arn:aws:iam::[0-9]{12}:role/.+ ]]; then
  echo "CF_DEPLOY_ROLE_ARN is invalid: ${DEPLOY_ROLE_ARN}"
  exit 1
fi

STACK_STATUS="$(aws cloudformation describe-stacks \
  --region "${REGION}" \
  --stack-name "${STACK_NAME}" \
  --query 'Stacks[0].StackStatus' \
  --output text \
  --no-cli-pager 2>/dev/null || true)"

if [[ "${STACK_STATUS}" == "ROLLBACK_COMPLETE" ]]; then
  echo "Stack ${STACK_NAME} is in ROLLBACK_COMPLETE. Deleting before redeploy..."
  aws cloudformation delete-stack \
    --region "${REGION}" \
    --stack-name "${STACK_NAME}" \
    --no-cli-pager
  aws cloudformation wait stack-delete-complete \
    --region "${REGION}" \
    --stack-name "${STACK_NAME}" \
    --no-cli-pager
fi

mapfile -t PARAM_OVERRIDES < <(
  jq -r '.Parameters | to_entries[] | "\(.key)=\(.value|tostring)"' "${PARAM_FILE}"
)

set +e
DEPLOY_ARGS=(
  --region "${REGION}"
  --template-file "infra/cloudformation/template.yml"
  --stack-name "${STACK_NAME}"
  --parameter-overrides "${PARAM_OVERRIDES[@]}"
)

DEPLOY_ARGS+=(--role-arn "${DEPLOY_ROLE_ARN}")

aws cloudformation deploy "${DEPLOY_ARGS[@]}" --no-cli-pager
DEPLOY_EXIT=$?
set -e

if [[ ${DEPLOY_EXIT} -ne 0 ]]; then
  echo "Deploy failed. FAILED events only:"
  STACK_EXISTS="$(aws cloudformation describe-stacks \
    --region "${REGION}" \
    --stack-name "${STACK_NAME}" \
    --query 'Stacks[0].StackName' \
    --output text \
    --no-cli-pager 2>/dev/null || true)"
  if [[ -n "${STACK_EXISTS}" && "${STACK_EXISTS}" != "None" ]]; then
    aws cloudformation describe-stack-events \
      --region "${REGION}" \
      --stack-name "${STACK_NAME}" \
      --query "StackEvents[?contains(ResourceStatus,'FAILED')].[LogicalResourceId,ResourceStatus,ResourceStatusReason]" \
      --output table \
      --no-cli-pager || true
  else
    echo "Stack not found yet; no events available."
  fi
  exit ${DEPLOY_EXIT}
fi
