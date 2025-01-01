#!/bin/bash

########################
# Import magic
########################
. ./configuration/demo-magic.sh
. ./configuration/helper_functions.sh
. ./configuration/env.sh
########################
clear

VSO_YAML_PATH="$YAML_PATH/vso"
DEMO_POD_VSO="basic-secret-pod"
DEMO_POD_CONTAINER_VSO="secret-test-container"

# Start demo here

caption "Vault Secrets Operator"
echo ""

p "Enable KV secrets engine and create a secret."
pe "vault secrets enable --path=secret kv-v2"
pe "vault kv put secret/vsodemo user=giraffe pass=salsa"
pe "vault kv get secret/vsodemo"

echo ""

p "Install Vault Secrets Operator with Helm."
helm repo add hashicorp https://helm.releases.hashicorp.com > /dev/null
pe "helm upgrade --install --create-namespace --namespace vault-secrets-operator vault-secrets-operator hashicorp/vault-secrets-operator"

wait_for_pod_by_label "app.kubernetes.io/name=vault-secrets-operator" "vault-secrets-operator"

echo ""

p "Enable Kubernetes auth in Vault."
pe "vault auth enable kubernetes"

p "Apply Kubernetes secret for Vault service account."
pe "cat $VSO_YAML_PATH/secret.yaml"
pe "kubectl apply -f $VSO_YAML_PATH/secret.yaml"

echo ""

p "Configure Kubernetes auth in Vault."
TOKEN_REVIEW_JWT=$(kubectl get secret default -n vault-secrets-operator -o go-template='{{ .data.token }}' | base64 --decode)
KUBE_CA_CERT=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.certificate-authority-data}' | base64 --decode)
KUBE_HOST=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.server}')

p "vault write auth/kubernetes/config 
        token_reviewer_jwt=\$TOKEN_REVIEW_JWT 
        kubernetes_host=\$KUBE_HOST 
        kubernetes_ca_cert=\$KUBE_CA_CERT"
vault write auth/kubernetes/config token_reviewer_jwt="$TOKEN_REVIEW_JWT" kubernetes_host="$KUBE_HOST" kubernetes_ca_cert="$KUBE_CA_CERT"

echo ""

p "Apply VaultConnection to connect Kubernetes to Vault."
pe "cat $VSO_YAML_PATH/VaultConnection.yaml"
pe "kubectl apply -f $VSO_YAML_PATH/VaultConnection.yaml"

echo ""

p "Apply VaultAuth for Kubernetes authentication."
pe "cat $VSO_YAML_PATH/VaultAuth.yaml"
pe "kubectl apply -f $VSO_YAML_PATH/VaultAuth.yaml"

echo ""

p "Create a Vault policy to read secrets."
p "vault policy write app-read-policy - <<EOF
path "secret/*" {
  capabilities = ["read"]
}
EOF"
vault policy write app-read-policy - <<EOF
path "secret/*" {
  capabilities = ["read"]
}
EOF

echo ""

p "Create a Vault role for service account authentication."
p "vault write auth/kubernetes/role/example 
        bound_service_account_names=default 
        bound_service_account_namespaces=default 
        policies=app-read-policy 
        ttl=24h"
vault write auth/kubernetes/role/example \
        bound_service_account_names=default \
        bound_service_account_namespaces=default \
        policies=app-read-policy \
        ttl=24h

echo ""

p "Apply VaultStaticSecret to sync secrets to Kubernetes."
pe "cat $VSO_YAML_PATH/VaultStaticSecret.yaml"
pe "kubectl apply -f $VSO_YAML_PATH/VaultStaticSecret.yaml"
pe "kubectl get secrets -n default"
pe "kubectl describe secrets static-secret1 -n default"

echo ""

p "Create a pod to consume the secret as env variable"
pe "cat $VSO_YAML_PATH/basic_secret_pod.yaml"
pe "kubectl apply -f $VSO_YAML_PATH/basic_secret_pod.yaml"
wait_for_pod_by_label "name=secret-test"

echo ""

p "Inspect the secret from within the pod"
pe "kubectl exec $DEMO_POD_VSO -- printenv | grep ENV_ ; echo"

p ""

# Cleanup
kubectl delete --force -f "$VSO_YAML_PATH/" > /dev/null
helm uninstall -n vault-secrets-operator vault-secrets-operator > /dev/null
vault secrets disable secret > /dev/null
vault auth disable kubernetes > /dev/null
vault policy delete app-read-policy > /dev/null

clear
