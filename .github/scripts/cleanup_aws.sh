#!/usr/bin/env bash
set -euo pipefail

export AWS_PAGER=""

REGION="${AWS_REGION:-$(aws configure get region)}"
if [[ -z "${REGION}" ]]; then
  echo "Missing region. Set AWS_REGION or configure a default AWS CLI region."
  exit 1
fi

STACKS=("$@")
if [[ ${#STACKS[@]} -eq 0 ]]; then
  STACKS=("welcome-to-the-django-prod" "welcome-to-the-django-iam")
fi

ROLES=("welcome-to-the-django-github-actions" "welcome-to-the-django-cfn-execution")

echo "Using region: ${REGION}"
aws sts get-caller-identity --no-cli-pager --output table

delete_started=()

for STACK in "${STACKS[@]}"; do
  if aws cloudformation describe-stacks \
    --region "${REGION}" \
    --stack-name "${STACK}" \
    --query 'Stacks[0].StackName' \
    --output text \
    --no-cli-pager >/dev/null 2>&1; then
    echo "Deleting stack: ${STACK}"
    aws cloudformation delete-stack \
      --region "${REGION}" \
      --stack-name "${STACK}" \
      --no-cli-pager
    delete_started+=("${STACK}")
  else
    echo "Stack not found: ${STACK}"
  fi
done

for STACK in "${delete_started[@]}"; do
  echo "Waiting delete complete: ${STACK}"
  aws cloudformation wait stack-delete-complete \
    --region "${REGION}" \
    --stack-name "${STACK}" \
    --no-cli-pager
  echo "Deleted: ${STACK}"
done

for ROLE in "${ROLES[@]}"; do
  aws iam get-role --role-name "${ROLE}" --no-cli-pager >/dev/null 2>&1 || continue
  mapfile -t ATTACHED_POLICY_ARNS < <(aws iam list-attached-role-policies --role-name "${ROLE}" --query 'AttachedPolicies[].PolicyArn' --output text --no-cli-pager 2>/dev/null | tr '\t' '\n' | sed '/^$/d')
  for POLICY_ARN in "${ATTACHED_POLICY_ARNS[@]}"; do
    aws iam detach-role-policy --role-name "${ROLE}" --policy-arn "${POLICY_ARN}" --no-cli-pager
  done
  mapfile -t INLINE_POLICIES < <(aws iam list-role-policies --role-name "${ROLE}" --query 'PolicyNames' --output text --no-cli-pager 2>/dev/null | tr '\t' '\n' | sed '/^$/d')
  for POLICY_NAME in "${INLINE_POLICIES[@]}"; do
    aws iam delete-role-policy --role-name "${ROLE}" --policy-name "${POLICY_NAME}" --no-cli-pager
  done
  aws iam delete-role --role-name "${ROLE}" --no-cli-pager
done

OIDC_PROVIDER_ARN="$(aws iam list-open-id-connect-providers \
  --query "OpenIDConnectProviderList[?contains(Arn, 'token.actions.githubusercontent.com')].Arn | [0]" \
  --output text \
  --no-cli-pager 2>/dev/null || true)"

if [[ -n "${OIDC_PROVIDER_ARN}" && "${OIDC_PROVIDER_ARN}" != "None" ]]; then
  echo "Deleting OIDC provider: ${OIDC_PROVIDER_ARN}"
  aws iam delete-open-id-connect-provider \
    --open-id-connect-provider-arn "${OIDC_PROVIDER_ARN}" \
    --no-cli-pager
else
  echo "OIDC provider not found: token.actions.githubusercontent.com"
fi

echo "Cleanup completed."