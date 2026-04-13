#!/usr/bin/env bash
# One-time bootstrap for GitHub Actions OIDC on AWS.
# Creates/reuses the GitHub OIDC provider and a bootstrap role.

set -euo pipefail

export AWS_PAGER=""

command -v aws >/dev/null 2>&1 || {
  echo "AWS CLI not found. Install AWS CLI and configure admin credentials first."
  exit 1
}

if [[ -z "${GITHUB_ORG:-}" ]]; then
  echo "Missing GITHUB_ORG. Example: export GITHUB_ORG=valentinavirga"
  exit 1
fi

if [[ -z "${GITHUB_REPO:-}" ]]; then
  echo "Missing GITHUB_REPO. Example: export GITHUB_REPO=welcome-to-the-django"
  exit 1
fi

REGION="${AWS_REGION:-$(aws configure get region)}"
if [[ -z "${REGION}" ]]; then
  echo "Missing AWS region. Set AWS_REGION or configure default region in AWS CLI."
  exit 1
fi

ACCOUNT_ID="$(aws sts get-caller-identity --query 'Account' --output text --no-cli-pager)"

GITHUB_BRANCH="main"
BOOTSTRAP_ROLE_NAME="welcome-to-the-django-bootstrap-oidc"
BOOTSTRAP_POLICY_ARN="arn:aws:iam::aws:policy/AdministratorAccess"

OIDC_PROVIDER_ARN="$(aws iam list-open-id-connect-providers \
  --query "OpenIDConnectProviderList[?contains(Arn, 'token.actions.githubusercontent.com')].Arn | [0]" \
  --output text \
  --no-cli-pager 2>/dev/null || true)"

if [[ -z "${OIDC_PROVIDER_ARN}" || "${OIDC_PROVIDER_ARN}" == "None" ]]; then
  echo "Creating GitHub OIDC provider..."
  OIDC_PROVIDER_ARN="$(aws iam create-open-id-connect-provider \
    --url "https://token.actions.githubusercontent.com" \
    --client-id-list "sts.amazonaws.com" \
    --thumbprint-list "6938fd4d98bab03faadb97b34396831e3780aea1" \
    --query 'OpenIDConnectProviderArn' \
    --output text \
    --no-cli-pager)"
else
  echo "OIDC provider exists: ${OIDC_PROVIDER_ARN}"
fi

TRUST_DOC="$(mktemp)"
trap 'rm -f "${TRUST_DOC}"' EXIT

cat > "${TRUST_DOC}" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${OIDC_PROVIDER_ARN}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:${GITHUB_ORG}/${GITHUB_REPO}:ref:refs/heads/${GITHUB_BRANCH}"
        }
      }
    }
  ]
}
EOF

ROLE_ARN="$(aws iam get-role \
  --role-name "${BOOTSTRAP_ROLE_NAME}" \
  --query 'Role.Arn' \
  --output text \
  --no-cli-pager 2>/dev/null || true)"

if [[ -z "${ROLE_ARN}" || "${ROLE_ARN}" == "None" ]]; then
  echo "Creating bootstrap role: ${BOOTSTRAP_ROLE_NAME}"
  ROLE_ARN="$(aws iam create-role \
    --role-name "${BOOTSTRAP_ROLE_NAME}" \
    --assume-role-policy-document "file://${TRUST_DOC}" \
    --description "Bootstrap role for GitHub Actions OIDC" \
    --query 'Role.Arn' \
    --output text \
    --no-cli-pager)"
else
  echo "Updating trust policy on existing role: ${BOOTSTRAP_ROLE_NAME}"
  aws iam update-assume-role-policy \
    --role-name "${BOOTSTRAP_ROLE_NAME}" \
    --policy-document "file://${TRUST_DOC}" \
    --no-cli-pager
fi

ATTACHED_POLICIES="$(aws iam list-attached-role-policies \
  --role-name "${BOOTSTRAP_ROLE_NAME}" \
  --query 'AttachedPolicies[].PolicyArn' \
  --output text \
  --no-cli-pager 2>/dev/null || true)"

if [[ " ${ATTACHED_POLICIES} " != *" ${BOOTSTRAP_POLICY_ARN} "* ]]; then
  aws iam attach-role-policy \
    --role-name "${BOOTSTRAP_ROLE_NAME}" \
    --policy-arn "${BOOTSTRAP_POLICY_ARN}" \
    --no-cli-pager
fi

echo ""
echo "✅ OIDC bootstrap completed"
echo "GitHub secrets to set:"
echo "AWS_REGION=${REGION}"
echo "AWS_ACCOUNT_ID=${ACCOUNT_ID}"
echo "AWS_ROLE_TO_ASSUME=${ROLE_ARN}"
