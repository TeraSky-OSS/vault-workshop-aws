#!/bin/bash

########################
# include the magic
########################
. ./configuration/demo-magic.sh
. ./configuration/helper_functions.sh
. ./configuration/env.sh
########################
clear

# Start demo here

caption "K8s Dynamic Secret"

p "After installing Vault with Helm, a 'vault' service account and secret were already created."
pe "cat $YAML_PATH/vault-sa.yaml"

echo ""

p "Now, let's create the ClusterRole for full access to secrets."
pe "cat $YAML_PATH/k8s-full-secrets-abilities-with-labels.yaml"
pe "kubectl apply -f $YAML_PATH/k8s-full-secrets-abilities-with-labels.yaml"

echo ""

p "Now, create the ClusterRoleBinding to bind the 'vault' service account to the above role."
pe "cat $YAML_PATH/vault-token-creator-binding.yaml"
pe "kubectl apply -f $YAML_PATH/vault-token-creator-binding.yaml"

echo ""

KUBE_VAULT_SECRET=$(kubectl get secret -n vault vault -o json | jq -r '.data')
KUBE_CA_CRT=$(echo $KUBE_VAULT_SECRET | jq -r '."ca.crt"' | base64 -d)
KUBE_VAULT_TOKEN=$(echo $KUBE_VAULT_SECRET | jq -r '.token' | base64 -d)
KUBE_API_URL=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.server}')

p "Enable the Kubernetes secret engine in Vault."
pe "vault secrets enable kubernetes"

echo ""

p "Configure Vault to connect to Kubernetes using the extracted credentials."
p "vault write -f kubernetes/config kubernetes_host=\$KUBE_API_URL kubernetes_ca_cert=\$KUBE_CA_CRT service_account_jwt=\$KUBE_VAULT_TOKEN"

vault write -f kubernetes/config \
    kubernetes_host=$KUBE_API_URL \
    kubernetes_ca_cert="$KUBE_CA_CRT" \
    service_account_jwt=$KUBE_VAULT_TOKEN

echo ""

p "Create a role in Vault for 'list' permissions on pods, valid for 10 minutes."
p "vault write kubernetes/roles/auto-managed-sa-and-role allowed_kubernetes_namespaces="*" token_default_ttl="10m" generated_role_rules='{"rules":[{"apiGroups":[""],"resources":["pods"],"verbs":["list"]}]}'"
vault write kubernetes/roles/auto-managed-sa-and-role \
    allowed_kubernetes_namespaces="*" \
    token_default_ttl="10m" \
    generated_role_rules='{"rules":[{"apiGroups":[""],"resources":["pods"],"verbs":["list"]}]}'

echo ""

p "Ask Vault to generate a dynamic service account and token with these permissions, limited to the 'default' namespace."
pe "vault write kubernetes/creds/auto-managed-sa-and-role kubernetes_namespace=default"

echo ""

p "Check the newly created service account in the default namespace."
pe "kubectl -n default get serviceaccount"

p "Done"
p ""

# Cleanup
vault secrets disable kubernetes/ > /dev/null
kubectl delete -f $YAML_PATH/k8s-full-secrets-abilities-with-labels.yaml > /dev/null
kubectl delete -f $YAML_PATH/vault-token-creator-binding.yaml > /dev/null

clear
