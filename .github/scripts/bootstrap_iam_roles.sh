#!/usr/bin/env bash
set -euo pipefail

: "${AWS_REGION:?AWS_REGION is required}"

STACK_NAME="${CF_STACK_NAME:-welcome-to-the-django-prod}"
ENVIRONMENT_NAME="${ENVIRONMENT_NAME:-prod}"
GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-valentinavirga/welcome-to-the-django}"
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"

echo "[bootstrap] region=${AWS_REGION} stack=${STACK_NAME} env=${ENVIRONMENT_NAME} repo=${GITHUB_REPOSITORY} branch=${GITHUB_BRANCH}"

STACK_STATUS="$(aws cloudformation describe-stacks \
  --region "${AWS_REGION}" \
  --stack-name "${STACK_NAME}" \
  --query 'Stacks[0].StackStatus' \
  --output text 2>/dev/null || true)"

if [[ "${STACK_STATUS}" == "ROLLBACK_COMPLETE" ]]; then
  echo "[bootstrap] stack is in ROLLBACK_COMPLETE, deleting..."
  aws cloudformation delete-stack \
    --region "${AWS_REGION}" \
    --stack-name "${STACK_NAME}"
  aws cloudformation wait stack-delete-complete \
    --region "${AWS_REGION}" \
    --stack-name "${STACK_NAME}"
fi

aws cloudformation deploy \
  --region "${AWS_REGION}" \
  --template-file "infra/cloudformation/template.yml" \
  --stack-name "${STACK_NAME}" \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    "EnvironmentName=${ENVIRONMENT_NAME}" \
    "GitHubRepository=${GITHUB_REPOSITORY}" \
    "GitHubBranch=${GITHUB_BRANCH}" \
    "BootstrapOnly=true" \
    "CreateDatabase=false"

OIDC_ROLE_ARN="$(aws cloudformation describe-stacks \
  --region "${AWS_REGION}" \
  --stack-name "${STACK_NAME}" \
  --query "Stacks[0].Outputs[?OutputKey=='GitHubActionsDeployRoleArn'].OutputValue" \
  --output text)"

CF_EXEC_ROLE_ARN="$(aws cloudformation describe-stacks \
  --region "${AWS_REGION}" \
  --stack-name "${STACK_NAME}" \
  --query "Stacks[0].Outputs[?OutputKey=='CloudFormationExecutionRoleArn'].OutputValue" \
  --output text)"

if [[ -z "${OIDC_ROLE_ARN}" || "${OIDC_ROLE_ARN}" == "None" ]]; then
  echo "[bootstrap] ERROR: unable to resolve GitHubActionsDeployRoleArn"
  exit 1
fi

if [[ -z "${CF_EXEC_ROLE_ARN}" || "${CF_EXEC_ROLE_ARN}" == "None" ]]; then
  echo "[bootstrap] ERROR: unable to resolve CloudFormationExecutionRoleArn"
  exit 1
fi

echo "[bootstrap] done. set these GitHub repo secrets:"
echo "AWS_ROLE_TO_ASSUME=${OIDC_ROLE_ARN}"
echo "CF_DEPLOY_ROLE_ARN=${CF_EXEC_ROLE_ARN}"
