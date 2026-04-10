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

if [[ ${#delete_started[@]} -eq 0 ]]; then
  echo "Nothing to delete."
  exit 0
fi

for STACK in "${delete_started[@]}"; do
  echo "Waiting delete complete: ${STACK}"
  aws cloudformation wait stack-delete-complete \
    --region "${REGION}" \
    --stack-name "${STACK}" \
    --no-cli-pager
  echo "Deleted: ${STACK}"
done

echo "Cleanup completed."