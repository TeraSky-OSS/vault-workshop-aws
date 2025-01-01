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

p "Vault Secret Operator for K8S with namespaces"
TYPE_SPEED=80
pe "kubectl wait pod $(kubectl get pods -A -o json | jq .items[].metadata.name | grep openldap- | tr -d '"') --for condition=Ready --timeout=120s"

echo 'dn: uid=hashicorp,ou=People,dc=ninjadude,dc=com
objectClass: top
objectClass: account
objectClass: posixAccount
objectClass: shadowAccount
cn: hashicorp
uid: hashicorp
uidNumber: 16859
gidNumber: 100
homeDirectory: /home/hashicorp
loginShell: /bin/bash
gecos: hashicorp
userPassword: {crypt}x
shadowLastChange: 0
shadowMax: 0
shadowWarning: 0' > ldapuser.ldif
ldapadd -x -H ldap://$(kubectl get svc openldap --output jsonpath='{.status.loadBalancer.ingress[0].hostname}'):389 -D "cn=admin,dc=ninjadude,dc=com" -w $(kubectl get secret openldap -o jsonpath="{.data.LDAP_ADMIN_PASSWORD}" | base64 --decode) -f ldapuser.ldif
ldapsearch -x -H ldap://$(kubectl get svc openldap --output jsonpath='{.status.loadBalancer.ingress[0].hostname}'):389 -b dc=ninjadude,dc=com -D "cn=admin,dc=ninjadude,dc=com" -w $(kubectl get secret openldap -o jsonpath="{.data.LDAP_ADMIN_PASSWORD}" | base64 --decode)
clear

p "create a new namespace in vault called integration"
pe "vault namespace create integration"
VAULT_NAMESPACE=integration

p "Enable the LDAP secret engine in integration namespace"
pe "vault secrets enable -namespace integration -path ldap ldap"

p "config the ldap integration"
p "vault write -namespace integration ldap/config 
    binddn=cn=admin,dc=ninjadude,dc=com 
    bindpass=$(kubectl get secret openldap -o jsonpath="{.data.LDAP_ADMIN_PASSWORD}" | base64 --decode) 
    url=ldap://$(kubectl get svc openldap --output jsonpath='{.status.loadBalancer.ingress[0].hostname}')"

vault write -namespace integration ldap/config \
    binddn=cn=admin,dc=ninjadude,dc=com \
    bindpass=$(kubectl get secret openldap -o jsonpath="{.data.LDAP_ADMIN_PASSWORD}" | base64 --decode) \
    url=ldap://$(kubectl get svc openldap --output jsonpath='{.status.loadBalancer.ingress[0].hostname}')

p "create a role for the ldap user"
p "vault write -namespace integration ldap/static-role/hashicorp 
    dn='uid=hashicorp,ou=People,dc=ninjadude,dc=com' 
    username='hashicorp' 
    rotation_period="60m""

vault write -namespace integration ldap/static-role/hashicorp \
    dn='uid=hashicorp,ou=People,dc=ninjadude,dc=com' \
    username='hashicorp' \
    rotation_period="60m"

p "now lets rotate the password of our bind ldap user."
pe "vault write -namespace integration -f ldap/rotate-role/hashicorp"

p "and read the new password generated for our ldap user."
pe "vault read -namespace integration ldap/static-cred/hashicorp"


p "install vault-secrets-operator using helm"
pe "helm repo add hashicorp https://helm.releases.hashicorp.com"
helm search repo hashicorp/vault-secrets-operator --devel > helm.txt
helm install --create-namespace --namespace vault-secrets-operator vault-secrets-operator hashicorp/vault-secrets-operator --version $(grep -o 'hashicorp/vault-secrets-operator[^"]*' helm.txt | cut -f2 -d$'\t')

kubectl wait deployment vault-secrets-operator-controller-manager -n vault-secrets-operator --for condition=Available=True --timeout=120s
kubectl wait pod $(kubectl get pods -n vault-secrets-operator -o json | jq .items[].metadata.name | grep vault-secrets-operator-controller | tr -d '"') -n vault-secrets-operator --for condition=Ready --timeout=120s

p "enabling kubernetes auth method in integration namespace at the kubeauth path"
pe "vault auth enable -namespace integration -path kubeauth kubernetes"


p "creating a cluster role binding for our k8s service account"
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

echo secret.yaml

pe "kubectl apply -f secret.yaml"

p "config kuberntes auth backend"
TOKEN_REVIEW_JWT=$(kubectl get secret default -n vault-secrets-operator -o go-template='{{ .data.token }}' | base64 --decode)
KUBE_CA_CERT=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.certificate-authority-data}' | base64 --decode)
KUBE_HOST=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.server}')
ISSUER=$(cat /home/ubuntu/issuer.txt)

vault write -namespace integration auth/kubeauth/config  \
        token_reviewer_jwt="$TOKEN_REVIEW_JWT" \
        kubernetes_host="$KUBE_HOST" \
        kubernetes_ca_cert="$KUBE_CA_CERT" \
        issuer="$ISSUER"

p "creating a auth role called secret-role"
vault write -namespace integration auth/kubeauth/role/secret-role \
        bound_service_account_names=* \
        bound_service_account_namespaces=* \
        policies=app-read-policy \
        ttl=24h

p "creating a policy to read secrets from the ldap path"
vault policy write -namespace integration app-read-policy - <<EOF
path "ldap/*" {
  capabilities = ["read"]
}
EOF

p "creating a VaultConnection to connect to vault"
echo "---
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultConnection
metadata:
  namespace: default
  name: vault-connect
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
kubectl apply -f VaultConnection.yaml

p "creating a VaultAuth to authenticate to vault"
echo '---
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultAuth
metadata:
  namespace: default
  name: vault-auth
spec:
  # required configuration
  # VaultConnectionRef of the corresponding VaultConnection CustomResource.
  # If no value is specified the Operator will default to the `default` VaultConnection,
  # configured in its own Kubernetes namespace.
  vaultConnectionRef: vault-connect
  # Method to use when authenticating to Vault.
  method: kubernetes
  # Mount to use when authenticating to auth method.
  mount: kubeauth
  # Kubernetes specific auth configuration, requires that the Method be set to kubernetes.
  kubernetes:
    # role to use when authenticating to Vault
    role: secret-role
    # ServiceAccount to use when authenticating to Vault
    # it is recommended to always provide a unique serviceAccount per Pod/application
    serviceAccount: default
  namespace: integration' > VaultAuth.yaml
cat VaultAuth.yaml
pe "kubectl apply -f VaultAuth.yaml"

p "creating a dynamic secret object"
echo "---
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultDynamicSecret
metadata:
  namespace: default
  name: example-dyn
spec:
  vaultAuthRef: vault-auth
  mount: ldap
  path: static-cred/hashicorp
  namespace: integration
  allowStaticCreds: true
  destination:
    create: true
    name: dynamic1" > dynamic1.yaml
cat dynamic1.yaml
pe "kubectl apply -f dynamic1.yaml"

p "lets see if our new secret was created and synced with vault."
pe "kubectl get secrets"
pe "kubectl get secrets dynamic1 -o yaml"

p "full info and features of vault VSO can be found on the official vault documentations at: https://developer.hashicorp.com/vault/docs/platform/k8s/vso"

p " *** DEMO END *** "

kubectl delete --force -f dynamic1.yaml
kubectl delete --force -f VaultAuth.yaml
kubectl delete --force -f VaultConnection.yaml
kubectl delete --force -f secret.yaml
helm uninstall -n vault-secrets-operator vault-secrets-operator
kubectl delete --force ns vault-secrets-operator
vault secrets disable -namespace integration ldap
vault secrets disable -namespace integration secrets
vault policy delete -namespace integration app-read-policy
vault auth disable -namespace integration kubeauth
vault namespace delete integration/
rm *.yaml
rm *.ldif
rm *.txt