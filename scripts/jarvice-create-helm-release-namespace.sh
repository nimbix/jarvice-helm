#!/bin/bash

NAMESPACE="jarvice-system"
TERRAFORM_CLUSTER=""

function usage {
    cat <<EOF

Usage:
    $0 [options]

Options:
    --namespace              <namespace>   JARVICE_SYSTEM_NAMESPACE
                                           (Default: $NAMESPACE)
    --terraform-cluster      <cluster>     Terraform cluster

Note:

    Terraform cluster is set in override.auto.tfvar.

    gke_cluster_00 is the Terraform cluster in the sample below:

#################################
### Google Cloud GKE clusters ###
#################################
gke = {  # Provision GKE infrastructure/clusters and deploy JARVICE
    gke_cluster_00 = {

    }
}
EOF
}

KUBECTL=$(type -p kubectl)
if [ -z "$KUBECTL" ]; then
    cat <<EOF
Could not find 'kubectl' in PATH. It may not be installed.
EOF
    exit 1
fi

HELM=$(type -p helm)
if [ -z "$HELM" ]; then
    cat <<EOF
Could not find 'helm' in PATH. It may not be installed.
EOF
    exit 1
fi

TERRAFORM=$(type -p terraform)
if [ -z "$HELM" ]; then
    cat <<EOF
Could not find 'terraform' in PATH. It may not be installed.
EOF
    exit 1
fi

while [ $# -gt 0 ]; do
    case $1 in
    --help)
	    usage
	    exit 0
	    ;;
	--namespace)
	    NAMESPACE=$2
	    shift; shift
	    ;;
	--terraform-cluster)
	    TERRAFORM_CLUSTER=$2
	    shift; shift
	    ;;
	*)
	    usage
	    exit 1
	    ;;
    esac
done

[ -z "$TERRAFORM_CLUSTER" ] && usage && exit 1

terraform_state="module.$TERRAFORM_CLUSTER.module.helm.helm_release.namespace[0]"

kube_context=$("$KUBECTL" config current-context)
[ "$?" -ne "0" ] && echo "Kubectl config invalid" && exit
read -p "Create $terraform_state for $kube_context? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Set KUBECONFIG to the desired cluster."
    exit 1
fi

"$KUBECTL" create ns $NAMESPACE
"$KUBECTL" annotate ns $NAMESPACE meta.helm.sh/release-name=$NAMESPACE
"$KUBECTL" annotate ns $NAMESPACE meta.helm.sh/release-namespace=default
"$KUBECTL" label ns $NAMESPACE app.kubernetes.io/managed-by=Helm
"$HELM" install $NAMESPACE namespace \
  --repo https://ameijer.github.io/k8s-as-helm \
  --version 1.1.0
"$TERRAFORM" import "$terraform_state" default/$NAMESPACE

