#!/bin/bash

########################
# include the magic
########################
. ./configuration/demo-magic.sh
. ./configuration/helper_functions.sh
. ./configuration/env.sh
########################
clear

PATH_YAML_VAULT_AGENT="$YAML_PATH/vault_agent"
TEST_POD_NAME="myapp"
TEST_POD_NAMESPACE="default"

# Start demo here

caption "Deploy Vault Agent"
echo ""

p "Enable Kubernetes authentication."
pe "vault auth enable kubernetes"

echo ""

p "Apply Vault service account secret."
pe "cat "$PATH_YAML_VAULT_AGENT/secret.yaml""
pe "kubectl apply -f "$PATH_YAML_VAULT_AGENT/secret.yaml""

echo ""

p "Configure Kubernetes auth."
TOKEN_REVIEW_JWT=$(kubectl get secret vault -n vault -o go-template='{{ .data.token }}' | base64 --decode)
KUBE_CA_CERT=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.certificate-authority-data}' | base64 --decode)
KUBE_HOST=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.server}')

p "vault write auth/kubernetes/config 
        token_reviewer_jwt=\$TOKEN_REVIEW_JWT 
        kubernetes_host=\$KUBE_HOST 
        kubernetes_ca_cert=\$KUBE_CA_CERT"
vault write auth/kubernetes/config token_reviewer_jwt="$TOKEN_REVIEW_JWT" kubernetes_host="$KUBE_HOST" kubernetes_ca_cert="$KUBE_CA_CERT"

echo ""

p "Enable KV secrets engine."
pe "vault secrets enable --path=secret kv-v2"

p "Write a secret to KV."
pe "vault kv put secret/myapp user=giraffe pass=salsa"

p "Read the secret from KV."
pe "vault kv get secret/myapp"

echo ""

p "Create a Vault policy for secret access."
p "vault policy write app-read-policy - <<EOF
path "secret/data/myapp" {
  capabilities = ["read"]
}
EOF"
vault policy write app-read-policy - <<EOF
path "secret/data/myapp" {
  capabilities = ["read"]
}
EOF

echo ""

p "Create a service account for the app."
pe "kubectl create serviceaccount myapp-sa -n $TEST_POD_NAMESPACE"

echo ""

p "Create a Vault role for the service account."
p "vault write auth/kubernetes/role/myapp-role 
        bound_service_account_names=myapp-sa 
        bound_service_account_namespaces=$TEST_POD_NAMESPACE 
        policies=app-read-policy 
        ttl=24h"  
vault write auth/kubernetes/role/myapp-role bound_service_account_names=myapp-sa bound_service_account_namespaces=$TEST_POD_NAMESPACE policies=app-read-policy ttl=24h

echo ""

p "Deploy the application pod to later inject secrets into it."
pe "cat "$PATH_YAML_VAULT_AGENT/myapp_pod.yaml""
pe "kubectl apply -f "$PATH_YAML_VAULT_AGENT/myapp_pod.yaml""
wait_for_pod_by_label "app=vault-agent-injector-test"
pe "kubectl get pods -n $TEST_POD_NAMESPACE"

echo ""
p "Read the secret from the pod."
pe "kubectl exec $TEST_POD_NAME -n $TEST_POD_NAMESPACE -- cat /vault/secrets/myapp.txt"

echo ""

p "Update the secret in Vault."
pe "vault kv put secret/myapp user=MyNewSecret pass=UpdatePODPlease"

echo ""

p "Verify the updated secret in the pod."
pe "vault kv get secret/myapp"
pe "kubectl exec $TEST_POD_NAME -n $TEST_POD_NAMESPACE -- cat /vault/secrets/myapp.txt"

p ""

# Cleanup
kubectl delete --force $PATH_YAML_VAULT_AGENT/ > /dev/null
kubectl delete serviceaccount myapp-sa > /dev/null
vault secrets disable secret > /dev/null
vault auth disable kubernetes > /dev/null

clear
