#!/usr/bin/env bash
# Deploys infra/iam/roles.yml as a bootstrap stack.
# Must be run ONCE by an admin with enough permissions before any other pipeline
# can run. After this stack exists, GitHub Actions uses the created roles.
#
# Required environment variables:
#   AWS_REGION        - AWS region
#   GITHUB_ORG        - GitHub organisation or user (e.g. my-org)
#   GITHUB_REPO       - Repository name (e.g. welcome-to-the-django)
#   GITHUB_BRANCH     - Branch allowed to assume the role (default: main)
#   IAM_STACK_NAME    - CloudFormation stack name (default: welcome-to-the-django-iam)

set -euo pipefail

export AWS_PAGER=""

REGION="${AWS_REGION:-$(aws configure get region)}"
if [[ -z "${REGION}" ]]; then
  echo "Missing AWS region. Set AWS_REGION or configure a default AWS CLI region."
  exit 1
fi

if [[ -z "${GITHUB_ORG:-}" ]]; then
  echo "Missing GITHUB_ORG. Export GITHUB_ORG before running this script locally."
  exit 1
fi

if [[ -z "${GITHUB_REPO:-}" ]]; then
  echo "Missing GITHUB_REPO. Export GITHUB_REPO before running this script locally."
  exit 1
fi

STACK_NAME="${IAM_STACK_NAME:-welcome-to-the-django-iam}"
GH_ORG="${GITHUB_ORG}"
GH_REPO="${GITHUB_REPO}"
GH_BRANCH="${GITHUB_BRANCH:-main}"
TEMPLATE="infra/iam/roles.yml"
EXISTING_OIDC_PROVIDER_ARN="${EXISTING_GITHUB_OIDC_PROVIDER_ARN:-}"

if [[ -z "${EXISTING_OIDC_PROVIDER_ARN}" ]]; then
  EXISTING_OIDC_PROVIDER_ARN="$(aws iam list-open-id-connect-providers \
    --query "OpenIDConnectProviderList[?contains(Arn, 'token.actions.githubusercontent.com')].Arn | [0]" \
    --output text \
    --no-cli-pager 2>/dev/null || true)"
fi

if [[ "${EXISTING_OIDC_PROVIDER_ARN}" == "None" ]]; then
  EXISTING_OIDC_PROVIDER_ARN=""
fi

echo "Deploying IAM roles stack: ${STACK_NAME} (region: ${REGION})"
if [[ -n "${EXISTING_OIDC_PROVIDER_ARN}" ]]; then
  echo "Reusing existing GitHub OIDC provider: ${EXISTING_OIDC_PROVIDER_ARN}"
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

set +e
DEPLOY_ARGS=(
  --region "${REGION}" \
  --template-file "${TEMPLATE}" \
  --stack-name "${STACK_NAME}" \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
      "GitHubOrg=${GH_ORG}" \
      "GitHubRepo=${GH_REPO}" \
      "GitHubBranch=${GH_BRANCH}"
)

if [[ -n "${EXISTING_OIDC_PROVIDER_ARN}" ]]; then
  DEPLOY_ARGS+=("ExistingGitHubOidcProviderArn=${EXISTING_OIDC_PROVIDER_ARN}")
fi

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

echo ""
echo "✅ IAM roles stack deployed successfully."
echo ""
echo "Role ARNs (add these as GitHub repository secrets):"
aws cloudformation describe-stacks \
  --region "${REGION}" \
  --stack-name "${STACK_NAME}" \
  --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
  --output table \
  --no-cli-pager
