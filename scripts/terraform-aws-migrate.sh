#!/bin/bash

set -e

TARGET_CLUSTER=""
UPDATE_TFSTATE=""
BACKUP_FILE="terraform.tfstate.migration.backup"
STATE_FILE="terraform.tfstate"
jxe_state="module.helm.helm_release.jarvice"
k8s_state="module.eks.aws_eks_cluster.this[0]"
vpc_state="module.vpc.aws_vpc.this[0]"

function usage {
	cat <<EOF
Usage:
	$0 [options]

Options:
	--cluster <eks_cluster>    AWS EKS cluster to migrate (required)
	--tfstate <eks_tfstate>    tfstate file of replacement EKS cluster (required)

Examples:
	$0 --cluster eks_cluster_01 --tfstate /tmp/jarvice-helm/terraform/terrafrom.tfstate

EOF
}

TERRAFORM=$(type -p terraform)
if [ -z "$TERRAFORM" ]; then
  cat <<EOF
Could not find 'terraform' in PATH. It may not be installed.
EOF
  exit 1
fi

JQ=$(type -p jq)
if [ -z "$JQ" ]; then
  cat <<EOF
Could not find 'jq' in PATH. It may not be installed.
EOF
  exit 1
fi

while [ $# -gt 0 ]; do
  case $1 in
    --help)
      usage
      exit 0
      ;;
    --cluster)
      TARGET_CLUSTER=$2
      shift; shift
      ;;
    --tfstate)
      UPDATE_TFSTATE=$2
      shift; shift
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done

[ -z "$TARGET_CLUSTER" ] && usage && exit 1
[ -z "UPDATE_TFSTATE" ] && usage && exit 1

function restore {
  mv ${BACKUP_FILE} ${STATE_FILE}
}
trap restore ERR

tmpfile=$(mktemp)
cp ${STATE_FILE} ${BACKUP_FILE}

function cleanup {
  rm -rf $tmpfile $BACKUP_FILE
}
trap cleanup EXIT

"$TERRAFORM" state list | grep ${TARGET_CLUSTER} | grep aws_eks_cluster.this || \
    (echo ${TARGET_CLUSTER} not EKS cluster && exit 1)

"$TERRAFORM" destroy -target=module.${TARGET_CLUSTER}.${jxe_state} -auto-approve
sleep 60
"$TERRAFORM" destroy -target=module.${TARGET_CLUSTER}.${k8s_state} -auto-approve
"$TERRAFORM" destroy -target=module.${TARGET_CLUSTER}.${vpc_state} -auto-approve
echo "Removing remaining resources for ${TARGET_CLUSTER}"
while [ $("$TERRAFORM" state list | grep ${TARGET_CLUSTER} | wc -l) -gt 0 ]; do
	for state in `"$TERRAFORM" state list | grep ${TARGET_CLUSTER}`; do
		"$TERRAFORM" destroy -target="$state" -auto-approve &> /dev/null
	done
done
echo "Updating ${STATE_FILE}"
"$JQ" '.resources[1:]' ${UPDATE_TFSTATE} > $tmpfile
update=$("$JQ" -n 'input | .resources += inputs' ${STATE_FILE} $tmpfile)
echo $update | tee ${STATE_FILE} &> /dev/null
cat <<EOF
Update complete. Note, jarvice-helm needs to pull in changes to support
AWS EKS Terraform module v18 and reinitialize terraform:

git pull --rebase origin master
terraform init --upgrade

EOF
