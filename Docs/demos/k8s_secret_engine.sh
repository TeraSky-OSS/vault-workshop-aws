#!/bin/bash

########################
# include the magic
########################
. demo-magic.sh

# hide the evidence
clear

p "Vault K8s Secret Engine Demo. - WIP"
TYPE_SPEED=80

#https://developer.hashicorp.com/vault/api-docs/secret/kubernetes

p "Lets create a new namespace in our k8s cluster called vault"
pe "kubectl create namespace vault"

p "Lets create a new service account in our k8s cluster called vault and generate a secret for it"
kubectl create -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: vault
  namespace: vault
---
apiVersion: v1
kind: Secret
metadata:
  name: vault
  namespace: vault
  annotations:
    kubernetes.io/service-account.name: vault
type: kubernetes.io/service-account-token
EOF

p "Lets create a new Cluster Role in our k8s cluster called k8s-full-secrets-abilities-with-labels"
kubectl create -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: k8s-full-secrets-abilities-with-labels
rules:
- apiGroups: [""]
  resources: ["namespaces"]
  verbs: ["get"]
- apiGroups: [""]
  resources: ["serviceaccounts", "serviceaccounts/token"]
  verbs: ["create", "update", "delete"]
- apiGroups: ["rbac.authorization.k8s.io"]
  resources: ["rolebindings", "clusterrolebindings"]
  verbs: ["create", "update", "delete"]
- apiGroups: ["rbac.authorization.k8s.io"]
  resources: ["roles", "clusterroles"]
  verbs: ["bind", "escalate", "create", "update", "delete"]
EOF

p "Lets create a Cluster Role Binding for our vault service account"
kubectl create -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: vault-token-creator-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: k8s-full-secrets-abilities-with-labels
subjects:
- kind: ServiceAccount
  name: vault
  namespace: vault
EOF

KUBE_VAULT_SECRET=$(kubectl get secret -n vault vault -o json | jq -r '.data')
KUBE_CA_CRT=$(echo $KUBE_VAULT_SECRET | jq -r '."ca.crt"' | base64 -d)
KUBE_VAULT_TOKEN=$(echo $KUBE_VAULT_SECRET | jq -r '.token' | base64 -d)
KUBE_API_URL=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.server}')

export VAULT_NAMESPACE="root"

p "lets enable Kubernetes secret engine in Vault"
vault secrets enable kubernetes
p "and configure it to connect to our k8s cluster"

vault write -f kubernetes/config \
    kubernetes_host=$KUBE_API_URL \
    kubernetes_ca_cert="$KUBE_CA_CRT" \
    service_account_jwt=$KUBE_VAULT_TOKEN

p "now we will create a new role in vault that will only allow list permissions on pods and will be valid for 10 minutes."

vault write kubernetes/roles/auto-managed-sa-and-role \
allowed_kubernetes_namespaces="*" \
token_default_ttl="10m" \
generated_role_rules='{"rules":[{"apiGroups":[""],"resources":["pods"],"verbs":["list"]}]}'

p "now lets ask vault to generate a dynamic service account and token with the above permissions and limit it only to the default namespace."

vault write kubernetes/creds/auto-managed-sa-and-role \
    kubernetes_namespace=default

p "lets look at our new service account"
kubectl get serviceaccount