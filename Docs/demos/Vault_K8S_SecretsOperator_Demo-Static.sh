#!/bin/bash

########################
# include the magic
########################
. demo-magic.sh

# hide the evidence
clear

# Put your stuff here
# pe = typed and executed
# p = just typed - not executed
# pe = print and execute immidiatly 

p "Vault Secret Operator for K8S DEMO."
TYPE_SPEED=80
p "enable KV secret engine in vault."
vault secrets enable --path=secret kv-v2
p "adding a KV secret to path secret/vsodemo"
vault kv put secret/vsodemo user=giraffe pass=salsa
p "reading the secret from path secret/vsodemo"
vault kv get secret/vsodemo

p "install vault-secrets-operator using helm"
pe "helm repo add hashicorp https://helm.releases.hashicorp.com"
helm search repo hashicorp/vault-secrets-operator --devel > helm.txt
p "helm install --create-namespace --namespace vault-secrets-operator vault-secrets-operator hashicorp/vault-secrets-operator --version $(grep -o 'hashicorp/vault-secrets-operator[^"]*' helm.txt | cut -f2 -d$'\t')"
helm install --create-namespace --namespace vault-secrets-operator vault-secrets-operator hashicorp/vault-secrets-operator --version $(grep -o 'hashicorp/vault-secrets-operator[^"]*' helm.txt | cut -f2 -d$'\t')

pe "kubectl wait deployment vault-secrets-operator-controller-manager -n vault-secrets-operator --for condition=Available=True --timeout=120s"
pe "kubectl wait pod $(kubectl get pods -n vault-secrets-operator -o json | jq .items[].metadata.name | grep vault-secrets-operator-controller | tr -d '"') -n vault-secrets-operator --for condition=Ready --timeout=120s"

p "enable K8S Auth"
pe "vault auth enable kubernetes"
p "create a secret for vault service account created by the helm deployment"
echo '---
apiVersion: v1
kind: Secret
metadata:
  name: default
  namespace: vault-secrets-operator
  annotations:
    kubernetes.io/service-account.name: default
type: kubernetes.io/service-account-token
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: vault-tokenreview
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
- kind: ServiceAccount
  name: default
  namespace: vault-secrets-operator' > secret.yaml
cat secret.yaml
pe "kubectl apply -f secret.yaml"

p "config kuberntes auth backend"
TOKEN_REVIEW_JWT=$(kubectl get secret default -n vault-secrets-operator -o go-template='{{ .data.token }}' | base64 --decode)
KUBE_CA_CERT=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.certificate-authority-data}' | base64 --decode)
KUBE_HOST=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.server}')
ISSUER=$(cat /home/ubuntu/issuer.txt)

# MANUALLY GET ISSUER
# kubectl proxy &
# export ISSUER=$(curl --silent http://127.0.0.1:8001/.well-known/openid-configuration | jq -r .issuer)
# kill %%

# echo $TOKEN_REVIEW_JWT
# echo $KUBE_CA_CERT
# echo $KUBE_HOST
# echo $ISSUER

p "vault write auth/kubernetes/config 
        token_reviewer_jwt="TOKEN_REVIEW_JWT" 
        kubernetes_host="KUBE_HOST" 
        kubernetes_ca_cert="KUBE_CA_CERT" 
        issuer="ISSUER""

vault write auth/kubernetes/config \
        token_reviewer_jwt="$TOKEN_REVIEW_JWT" \
        kubernetes_host="$KUBE_HOST" \
        kubernetes_ca_cert="$KUBE_CA_CERT" \
        issuer="$ISSUER"


p "creating a VaultConnection to connect to vault"
echo "---
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultConnection
metadata:
  namespace: default
  name: example
spec:
  # required configuration
  # address to the Vault server.
  address: $(echo $VAULT_ADDR)
  # skip TLS verification for TLS connections to Vault.
  skipTLSVerify: true

  # optional configuration
  # HTTP headers to be included in all Vault requests.
  # headers: []
  # TLS server name to use as the SNI host for TLS connections.
  # tlsServerName: ""
  # the trusted PEM encoded CA certificate chain stored in a Kubernetes Secret
  # caCertSecretRef: """ > VaultConnection.yaml
cat VaultConnection.yaml
pe "kubectl apply -f VaultConnection.yaml"

p "creating a VaultAuth to authenticate to vault"
echo "---
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultAuth
metadata:
  namespace: default
  name: example
spec:
  # required configuration
  # VaultConnectionRef of the corresponding VaultConnection CustomResource.
  # If no value is specified the Operator will default to the `default` VaultConnection,
  # configured in its own Kubernetes namespace.
  vaultConnectionRef: example
  # Method to use when authenticating to Vault.
  method: kubernetes
  # Mount to use when authenticating to auth method.
  mount: kubernetes
  # Kubernetes specific auth configuration, requires that the Method be set to kubernetes.
  kubernetes:
    # role to use when authenticating to Vault
    role: example
    # ServiceAccount to use when authenticating to Vault
    # it is recommended to always provide a unique serviceAccount per Pod/application
    serviceAccount: default" > VaultAuth.yaml
cat VaultAuth.yaml
pe "kubectl apply -f VaultAuth.yaml"

p "Create vault policy to read secrets from defined path:"
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

p "create vault role to bound to service account and policy for authentication:"
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

p "creating a VaultStaticSecret to mount the secret from vault to a k8s secret."
echo "---
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultStaticSecret
metadata:
  namespace: default
  name: example
spec:
  vaultAuthRef: example
  mount: secret
  type: kv-v2
  path: vsodemo
  refreshAfter: 60s
  destination:
    create: true
    name: static-secret1" > VaultStaticSecret.yaml
cat VaultStaticSecret.yaml
pe "kubectl apply -f VaultStaticSecret.yaml"
pe "kubectl get secrets"
pe "kubectl describe secrets static-secret1"

p "create a pod and mount basic-secret in it"
echo 'apiVersion: v1
kind: Pod
metadata:
  name: basic-secret-pod
  labels:
    name: secret-test
spec:
  volumes:
  - name: secret-volume
    secret:
      secretName: static-secret1
  containers:
  - name: secret-test-container
    image: busybox
    command: ["sh", "-c", "sleep 4800"]
    env:
      - 
        name: ENV_USER
        valueFrom:
          secretKeyRef:
            name: static-secret1
            key: user
      - 
        name: ENV_PASS
        valueFrom:
          secretKeyRef:
            name: static-secret1
            key: pass
    volumeMounts:
    - name: secret-volume
      readOnly: true
      mountPath: "/etc/secret-volume"' > basic_secret_pod.yaml
cat basic_secret_pod.yaml
pe "kubectl apply -f basic_secret_pod.yaml"

pe "kubectl wait pod $(kubectl get pods -A -o json | jq .items[].metadata.name | grep basic-secret-pod | tr -d '"') --for condition=Ready --timeout=120s"
pe "kubectl exec $(kubectl get pods -A -o json | jq .items[].metadata.name | grep basic-secret-pod | tr -d '"') -- printenv | grep ENV_ ; echo"
pe "kubectl exec $(kubectl get pods -A -o json | jq .items[].metadata.name | grep basic-secret-pod | tr -d '"') --container secret-test-container -- cat /etc/secret-volume/user ; echo"
pe "kubectl exec $(kubectl get pods -A -o json | jq .items[].metadata.name | grep basic-secret-pod | tr -d '"') --container secret-test-container -- cat /etc/secret-volume/pass ; echo"
pe "kubectl exec $(kubectl get pods -A -o json | jq .items[].metadata.name | grep basic-secret-pod | tr -d '"') --container secret-test-container -- printenv | grep ENV_ ; echo"

p "full info and features of vault VSO can be found on the official vault documentations at:"
p "https://developer.hashicorp.com/vault/docs/platform/k8s/vso"

p " *** DEMO END *** "

kubectl delete --force -f basic_secret_pod.yaml
kubectl delete --force -f VaultStaticSecret.yaml
kubectl delete --force -f VaultAuth.yaml
kubectl delete --force -f VaultConnection.yaml
kubectl delete --force -f secret.yaml
helm uninstall -n vault-secrets-operator vault-secrets-operator
kubectl delete --force ns vault-secrets-operator
vault secrets disable secret
vault policy delete app-read-policy
vault auth disable kubernetes
rm basic_secret_pod.yaml
rm VaultStaticSecret.yaml
rm VaultAuth.yaml
rm VaultConnection.yaml
rm secret.yaml