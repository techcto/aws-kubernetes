#!/usr/bin/env bash
# Interactive CLI for creating and managing a Solodev EKS cluster (eks.yaml).
#
# Install:
#   curl -O https://solodev-kubernetes.s3.amazonaws.com/kcmd.sh && chmod 700 kcmd.sh
set -euo pipefail

# ── Color ─────────────────────────────────────────────────────────────────────
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  BOLD="$(printf '\033[1m')"
  DIM="$(printf '\033[2m')"
  BLUE="$(printf '\033[34m')"
  GREEN="$(printf '\033[32m')"
  YELLOW="$(printf '\033[33m')"
  RED="$(printf '\033[31m')"
  RESET="$(printf '\033[0m')"
else
  BOLD="" DIM="" BLUE="" GREEN="" YELLOW="" RED="" RESET=""
fi

ASSUME_YES="${ASSUME_YES:-false}"
DRY_RUN="${DRY_RUN:-false}"
REGION="${REGION:-us-east-1}"
STATE_DIR=".kcmd"
TEMPLATE_URL="https://s3.amazonaws.com/solodev-kubernetes/cloudformation/eks.yaml"

# ── Helpers ───────────────────────────────────────────────────────────────────
say()     { printf '%b\n' "$*"; }
die()     { say "${RED}Error:${RESET} $*" >&2; exit 1; }
section() { say ""; say "${BOLD}${BLUE}$*${RESET}"; say "${DIM}------------------------------------------------------------${RESET}"; }
success() { say "${GREEN}$*${RESET}"; }
warn()    { say "${YELLOW}$*${RESET}"; }

run() {
  printf '%s' "${DIM}+"
  printf ' %q' "$@"
  printf '%b\n' "${RESET}"
  if [[ "$DRY_RUN" != "true" ]]; then "$@"; fi
}

confirm() {
  local prompt="${1:-Continue?}"
  if [[ "$ASSUME_YES" == "true" || "$DRY_RUN" == "true" ]]; then return 0; fi
  local answer
  read -r -p "${prompt} [y/N] " answer
  case "$answer" in y|Y|yes|YES) return 0 ;; *) die "Canceled." ;; esac
}

prompt_value() {
  local label="$1" default_value="${2:-}" value
  if [[ -n "$default_value" ]]; then
    read -r -p "${label} [${default_value}]: " value
    printf '%s' "${value:-$default_value}"
  else
    read -r -p "${label}: " value
    printf '%s' "$value"
  fi
}

pick_aws_profile() {
  local profiles=()
  while IFS= read -r line; do
    line="${line%$'\r'}"
    [[ -n "$line" ]] && profiles+=("$line")
  done < <(aws configure list-profiles 2>/dev/null | sort)

  if [[ ${#profiles[@]} -eq 0 ]]; then
    read -r -p "AWS profile to use: " value >&2
    printf '%s' "$value"
    return
  fi

  printf '%b\n' "${BOLD}Available AWS profiles:${RESET}" >&2
  local i=1
  for p in "${profiles[@]}"; do
    printf '  %d. %s\n' "$i" "$p" >&2
    (( i++ ))
  done
  printf '\n' >&2

  local choice
  read -r -p "Choose a profile [1-${#profiles[@]}] or type a name: " choice

  if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#profiles[@]} )); then
    printf '%s' "${profiles[$((choice - 1))]}"
  elif [[ -n "$choice" ]]; then
    printf '%s' "$choice"
  else
    die "No profile selected."
  fi
}

stackOutput() {
  aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" --region "$REGION" --profile "$AWS_PROFILE" \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" --output text
}

# ── Bootstrap ─────────────────────────────────────────────────────────────────
# Resolves AWS_PROFILE / STACK_NAME / REGION and persists them per-developer in
# ./.kcmd/ (gitignored) so you don't have to pass them on every invocation.
bootstrap() {
  if [[ -f .env ]]; then
    set -a
    # shellcheck source=/dev/null
    source .env 2>/dev/null || true
    set +a
  fi

  mkdir -p "$STATE_DIR"

  if [[ -z "${AWS_PROFILE:-}" ]]; then
    if [[ -f "$STATE_DIR/aws.profile" ]]; then
      AWS_PROFILE="$(cat "$STATE_DIR/aws.profile")"
    else
      AWS_PROFILE="$(pick_aws_profile)"
      printf '%s\n' "$AWS_PROFILE" > "$STATE_DIR/aws.profile"
    fi
  fi
  export AWS_PROFILE

  local stack_file="$STATE_DIR/stack.${USER:-${USERNAME:-default}}"
  if [[ -z "${STACK_NAME:-}" ]]; then
    if [[ -f "$stack_file" ]]; then
      STACK_NAME="$(cat "$stack_file")"
    else
      STACK_NAME="$(prompt_value "Stack/cluster name" "eks-${RANDOM}")"
      printf '%s\n' "$STACK_NAME" > "$stack_file"
    fi
  else
    printf '%s\n' "$STACK_NAME" > "$stack_file"
  fi
  export STACK_NAME REGION

  export KUBECONFIG="${KUBECONFIG:-${STATE_DIR}/${STACK_NAME}.kubeconfig}"

  say "${DIM}Stack: ${STACK_NAME}  |  Profile: ${AWS_PROFILE}  |  Region: ${REGION}${RESET}"
}

# Only needed by commands that talk to an already-running cluster.
resolveClusterInfo() {
  EKSName="$(stackOutput EKSClusterName)"
  KubernetesAdminRole="$(stackOutput SysOpsAdminRoleArn)"
  [[ -n "$EKSName" && "$EKSName" != "None" ]] || die "Stack ${STACK_NAME} has no EKSClusterName output - has it finished creating? Run './kcmd.sh status'."
  export EKSName KubernetesAdminRole
}

# ── Cluster lifecycle ─────────────────────────────────────────────────────────
cmd_create_cluster() {
  section "Create EKS cluster: ${STACK_NAME}"

  local params_file="${STATE_DIR}/${STACK_NAME}.params.json"
  if [[ ! -f "$params_file" ]]; then
    say "No saved parameters for ${STACK_NAME} yet - let's set the required ones."
    say "${DIM}(everything else in eks.yaml has a sensible default - edit ${params_file} directly to change more later)${RESET}"
    local vpc subnet1 zone keypair
    vpc="$(prompt_value "VPC ID")"
    subnet1="$(prompt_value "Private subnet 1 ID")"
    zone="$(prompt_value "Cluster DNS zone (ClusterZone)")"
    keypair="$(prompt_value "EC2 key pair name (blank for none)" "")"
    cat > "$params_file" <<JSON
[
  {"ParameterKey": "VPCID", "ParameterValue": "${vpc}"},
  {"ParameterKey": "PrivateSubnet1ID", "ParameterValue": "${subnet1}"},
  {"ParameterKey": "ClusterZone", "ParameterValue": "${zone}"},
  {"ParameterKey": "KeyPairName", "ParameterValue": "${keypair}"}
]
JSON
    success "Saved parameters to ${params_file}."
  fi

  confirm "Create stack ${STACK_NAME} in ${REGION} from ${TEMPLATE_URL}?"

  run aws cloudformation create-stack \
    --stack-name "$STACK_NAME" --region "$REGION" --profile "$AWS_PROFILE" \
    --disable-rollback --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
    --parameters "file://${params_file}" \
    --template-url "$TEMPLATE_URL"

  say "Waiting for the stack to finish (this typically takes 15-20 minutes)..."
  run aws cloudformation wait stack-create-complete \
    --stack-name "$STACK_NAME" --region "$REGION" --profile "$AWS_PROFILE"

  success "Stack ${STACK_NAME} created."
  cmd_kubeconfig
}

cmd_delete_cluster() {
  section "Delete EKS cluster: ${STACK_NAME}"
  warn "This deletes the stack and everything it created. This cannot be undone."
  confirm "Delete stack ${STACK_NAME} in ${REGION}?"
  run aws cloudformation delete-stack --stack-name "$STACK_NAME" --region "$REGION" --profile "$AWS_PROFILE"
  say "Waiting for the stack to finish deleting..."
  run aws cloudformation wait stack-delete-complete --stack-name "$STACK_NAME" --region "$REGION" --profile "$AWS_PROFILE"
  success "Stack ${STACK_NAME} deleted."
}

cmd_kubeconfig() {
  section "Update kubeconfig"
  resolveClusterInfo
  addTrustPolicy
  run aws eks --region "$REGION" update-kubeconfig \
    --name "$EKSName" --role-arn "$KubernetesAdminRole" --profile "$AWS_PROFILE" --kubeconfig "$KUBECONFIG"
  success "Kubeconfig written to ${KUBECONFIG}."
}

addTrustPolicy() {
  [[ -n "${USER_ARN:-}" ]] || return 0
  local role_name; role_name="$(echo "$KubernetesAdminRole" | awk -F/ '{print $NF}')"
  aws iam get-role --role-name "${role_name}" --profile "${AWS_PROFILE}" > "${STATE_DIR}/role-trust-policy.json"
  local policy
  policy="$(printf '{"Effect":"Allow","Principal":{"AWS":"%s"},"Action":"sts:AssumeRole"}' "$USER_ARN")"
  jq --argjson obj "$policy" \
    '.Role.AssumeRolePolicyDocument.Statement += [$obj] | .Role.AssumeRolePolicyDocument' \
    "${STATE_DIR}/role-trust-policy.json" > "${STATE_DIR}/output-policy.json"
  run aws iam update-assume-role-policy \
    --role-name "${role_name}" --policy-document "file://${STATE_DIR}/output-policy.json" --profile "${AWS_PROFILE}"
  rm -f "${STATE_DIR}/role-trust-policy.json" "${STATE_DIR}/output-policy.json"
}

cmd_status() {
  section "Cluster status"
  say "Stack:      ${STACK_NAME}"
  say "Region:     ${REGION}"
  say "Profile:    ${AWS_PROFILE}"
  say "Kubeconfig: ${KUBECONFIG}"
  local stack_status
  stack_status="$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" --profile "$AWS_PROFILE" --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo "NOT FOUND")"
  say "Stack state: ${stack_status}"
  [[ "$stack_status" == *COMPLETE* ]] || return 0
  say ""
  cmd_list
}

# ── Operations ────────────────────────────────────────────────────────────────
cmd_list() {
  section "Pods (all namespaces)"
  kubectl --kubeconfig="$KUBECONFIG" get svc
  kubectl --kubeconfig="$KUBECONFIG" get pods --all-namespaces
}

cmd_pod() {
  local name="${1:-}"; [[ -n "$name" ]] || name="$(prompt_value "Pod name")"
  kubectl --kubeconfig="$KUBECONFIG" get pod "$name"
}

cmd_logs() {
  local name="${1:-}"; [[ -n "$name" ]] || name="$(prompt_value "Pod name")"
  kubectl --kubeconfig="$KUBECONFIG" -n kubernetes-dashboard logs --follow "$name"
}

cmd_token() {
  section "Admin token"
  kubectl --kubeconfig="$KUBECONFIG" -n kube-system describe secret \
    "$(kubectl --kubeconfig="$KUBECONFIG" -n kube-system get secret | grep solodev-admin | awk '{print $1}')"
}

cmd_proxy() {
  cmd_token
  section "Port-forward Dashboard"
  kubectl --kubeconfig="$KUBECONFIG" port-forward -n kubernetes-dashboard service/kubernetes-dashboard 8080:80
}

cmd_update() {
  section "Update Helm repos"
  run helm --kubeconfig "$KUBECONFIG" repo update
  helm --kubeconfig "$KUBECONFIG" repo list
}

# Requires NAMESPACE, RELEASE, SECRET, PASSWORD, DBPASSWORD set by the caller.
# Installs from the "solodev" Helm repo (see charts/deploy.sh) - run
# `helm repo add solodev http://solodev-kubernetes.s3-website-us-east-1.amazonaws.com/charts`
# once before using this.
cmd_install() {
  local name="${1:-}"; [[ -n "$name" ]] || name="$(prompt_value "Release name")"
  section "Install release: ${name}"
  run helm --kubeconfig "$KUBECONFIG" install --namespace "${NAMESPACE}" --name "${name}" "solodev/${RELEASE}" \
    --set solodev.settings.appSecret="${SECRET}" --set solodev.settings.appPassword="${PASSWORD}" --set solodev.settings.dbPassword="${DBPASSWORD}"
}

cmd_init_secret() {
  local name="${1:-}"; [[ -n "$name" ]] || name="$(prompt_value "Namespace")"
  run kubectl --kubeconfig="$KUBECONFIG" create namespace "$name"
}

cmd_delete() {
  local name="${1:-}"; [[ -n "$name" ]] || name="$(prompt_value "Release name to delete")"
  section "Delete release: ${name}"
  confirm "Delete Helm release ${name} and its PVCs?"
  run helm --kubeconfig "$KUBECONFIG" delete "${name}"
  run kubectl --kubeconfig "$KUBECONFIG" delete --namespace "${name}" --all pvc
}

cmd_clean() {
  local name="${1:-}"; [[ -n "$name" ]] || name="$(prompt_value "Namespace to clean")"
  section "Clean namespace: ${name}"
  confirm "Force-delete ALL resources in namespace ${name}?"
  run kubectl --kubeconfig="$KUBECONFIG" delete \
    --all daemonsets,replicasets,statefulsets,services,ingress,deployments,pods,rc,configmap \
    --namespace="${name}" --grace-period=0 --force
  run kubectl --kubeconfig="$KUBECONFIG" delete --namespace "${name}" --all pvc,pv
}

cmd_ssh() {
  local host="${1:-}"; [[ -n "$host" ]] || host="$(prompt_value "Bastion-reachable host")"
  say "ssh -i ${KEY:-<KEY>} ec2-user@${host} -o \"proxycommand ssh -W %h:%p -i ${KEY:-<KEY>} ec2-user@${BASTION:-<BASTION>}\""
}

# ── Usage ─────────────────────────────────────────────────────────────────────
usage() {
  cat <<'EOFUSAGE'
Usage:
  ./kcmd.sh [options]                    Open interactive menu
  ./kcmd.sh [options] create cluster     Create the EKS cluster (eks.yaml)
  ./kcmd.sh [options] delete cluster     Delete the EKS cluster and all resources
  ./kcmd.sh [options] kubeconfig         Write/refresh the kubeconfig
  ./kcmd.sh [options] status             Show stack + pod status
  ./kcmd.sh [options] ls                 List all pods and services
  ./kcmd.sh [options] pod <name>         Show a pod
  ./kcmd.sh [options] logs <name>        Follow a pod's logs
  ./kcmd.sh [options] token              Print admin token
  ./kcmd.sh [options] proxy              Open Dashboard (port-forward)
  ./kcmd.sh [options] update             Update Helm repos
  ./kcmd.sh [options] install <name>     Install a release (needs NAMESPACE/RELEASE/SECRET/PASSWORD/DBPASSWORD)
  ./kcmd.sh [options] delete <name>      Delete a Helm release + PVCs
  ./kcmd.sh [options] clean <namespace>  Force-clean a namespace
  ./kcmd.sh [options] initsecret <ns>    Create a namespace
  ./kcmd.sh [options] ssh <host>         Print a bastion-proxied ssh command
  ./kcmd.sh [options] help               Show this help

Options:
  -y, --yes          Skip confirmation prompts
  --dry-run          Print commands without running them
  --region <name>    AWS region, default: us-east-1
  -h, --help         Show this help

Environment:
  AWS_PROFILE    Override profile (bypasses .kcmd/aws.profile prompt)
  STACK_NAME     Override stack/cluster name (bypasses .kcmd/stack.<user> prompt)
  REGION         Override region (default: us-east-1)
  USER_ARN       IAM user/role ARN to also grant cluster-admin access to
  KUBECONFIG     Override kubeconfig path (default: .kcmd/<stack>.kubeconfig)
EOFUSAGE
}

# ── Interactive menu ──────────────────────────────────────────────────────────
menu() {
  while true; do
    clear 2>/dev/null || true
    say "${BOLD}${BLUE}Solodev EKS kcmd${RESET}"
    say "${DIM}Stack: ${STACK_NAME}  |  Profile: ${AWS_PROFILE}  |  Region: ${REGION}${RESET}"
    say ""
    say "${BOLD}Cluster${RESET}"
    say "  1. Create cluster"
    say "  2. Delete cluster"
    say "  3. Refresh kubeconfig"
    say "  4. Show status"
    say ""
    say "${BOLD}Operations${RESET}"
    say "  5. List pods"
    say "  6. Update Helm repos"
    say "  7. Get admin token"
    say ""
    say "${BOLD}Access${RESET}"
    say "  8. Port-forward Dashboard"
    say ""
    say "${BOLD}Maintenance${RESET}"
    say "  9. Delete release"
    say " 10. Clean namespace"
    say ""
    say " 11. Exit"
    say ""

    local choice
    read -r -p "Choose an option: " choice

    case "$choice" in
      1)  cmd_create_cluster ;;
      2)  cmd_delete_cluster ;;
      3)  cmd_kubeconfig ;;
      4)  cmd_status ;;
      5)  cmd_list ;;
      6)  cmd_update ;;
      7)  cmd_token ;;
      8)  cmd_proxy ;;
      9)  cmd_delete ;;
      10) cmd_clean ;;
      11|q|quit|exit) say "Bye."; return 0 ;;
      *)  warn "Unknown option: ${choice}" ;;
    esac

    say ""
    read -r -p "Press Enter to continue..." _
  done
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -y|--yes)   ASSUME_YES=true; shift ;;
      --dry-run)  DRY_RUN=true;    shift ;;
      --region)   REGION="${2:-}"; [[ -n "$REGION" ]] || die "--region requires a value"; shift 2 ;;
      -h|--help)  usage; exit 0 ;;
      *) break ;;
    esac
  done

  local cmd="${1:-menu}"
  shift || true

  bootstrap

  case "$cmd" in
    menu|ui)    menu ;;
    create)
      case "${1:-}" in
        cluster) cmd_create_cluster ;;
        *)       die "Usage: ./kcmd.sh create cluster" ;;
      esac
      ;;
    delete)
      case "${1:-}" in
        cluster) cmd_delete_cluster ;;
        *)       cmd_delete "${1:-}" ;;
      esac
      ;;
    kubeconfig) cmd_kubeconfig ;;
    status)     resolveClusterInfo 2>/dev/null || true; cmd_status ;;
    ls|list)    resolveClusterInfo >/dev/null; cmd_list ;;
    pod)        resolveClusterInfo >/dev/null; cmd_pod "${1:-}" ;;
    logs)       resolveClusterInfo >/dev/null; cmd_logs "${1:-}" ;;
    token)      resolveClusterInfo >/dev/null; cmd_token ;;
    proxy)      resolveClusterInfo >/dev/null; cmd_proxy ;;
    update)     resolveClusterInfo >/dev/null; cmd_update ;;
    install)    resolveClusterInfo >/dev/null; cmd_install "${1:-}" ;;
    initsecret) resolveClusterInfo >/dev/null; cmd_init_secret "${1:-}" ;;
    clean)      resolveClusterInfo >/dev/null; cmd_clean "${1:-}" ;;
    ssh)        cmd_ssh "${1:-}" ;;
    help)       usage ;;
    *)          die "Unknown command: ${cmd}. Run ./kcmd.sh help." ;;
  esac
}

main "$@"
