#!/usr/bin/env bash
set -euo pipefail

# Provision publication repositories in the seller account, not application stacks.
if [[ -n "${DIRECT_PULL_ACCOUNT_ID:-}" && ! "$DIRECT_PULL_ACCOUNT_ID" =~ ^[0-9]{12}$ ]]; then
  echo 'DIRECT_PULL_ACCOUNT_ID must be a 12-digit AWS account ID.' >&2
  exit 1
fi
partition=$(aws sts get-caller-identity --query Arn --output text | cut -d: -f2)
workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

for repository in "$MP_AUTH_REPOSITORY" "$MP_API_REPOSITORY" "$MP_WEB_REPOSITORY" "$MP_METRICS_REPOSITORY" "$MP_CHART_REPOSITORY"; do
  if ! aws ecr describe-repositories --repository-names "$repository" > /dev/null 2> "$workdir/error"; then
    if ! grep -q 'RepositoryNotFoundException' "$workdir/error"; then
      cat "$workdir/error" >&2
      exit 1
    fi
    aws ecr create-repository --repository-name "$repository" \
      --image-tag-mutability IMMUTABLE --image-scanning-configuration scanOnPush=true > /dev/null
  fi

  # Keep unrelated policy statements when updating this release's sharing grant.
  if [[ -n "${DIRECT_PULL_ACCOUNT_ID:-}" ]]; then
    if aws ecr get-repository-policy --repository-name "$repository" \
      --query policyText --output text > "$workdir/policy.json" 2> "$workdir/error"; then
      :
    elif grep -q 'RepositoryPolicyNotFoundException' "$workdir/error"; then
      printf '{"Version":"2012-10-17","Statement":[]}\n' > "$workdir/policy.json"
    else
      cat "$workdir/error" >&2
      exit 1
    fi
    jq --arg principal "arn:$partition:iam::$DIRECT_PULL_ACCOUNT_ID:root" '
      .Statement = ((.Statement // [] | if type == "array" then . else [.] end
        | map(select(.Sid != "DirectCrossAccountPull"))) + [{
          Sid: "DirectCrossAccountPull", Effect: "Allow",
          Principal: {AWS: $principal},
          Action: ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer", "ecr:BatchCheckLayerAvailability"]
        }])
    ' "$workdir/policy.json" > "$workdir/shared-policy.json"
    aws ecr set-repository-policy --repository-name "$repository" \
      --policy-text "file://$workdir/shared-policy.json" > /dev/null
  fi
done
