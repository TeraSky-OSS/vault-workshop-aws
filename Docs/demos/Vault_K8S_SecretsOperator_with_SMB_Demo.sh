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

p "Vault Secret Operator for K8S + ldap user + SMB csi DEMO."
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

p "Enable the LDAP secret engine:"
pe "vault secrets enable ldap"
p "Configure the credentials that Vault uses to communicate with LDAP to generate passwords:"
p "vault write ldap/config 
    binddn=cn=admin,dc=ninjadude,dc=com 
    bindpass=password 
    url=ldap://$(kubectl get svc openldap --output jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
vault write ldap/config \
    binddn=cn=admin,dc=ninjadude,dc=com \
    bindpass=$(kubectl get secret openldap -o jsonpath="{.data.LDAP_ADMIN_PASSWORD}" | base64 --decode) \
    url=ldap://$(kubectl get svc openldap --output jsonpath='{.status.loadBalancer.ingress[0].hostname}')

p "Rotate the root password so only Vault knows the credentials:"
pe "vault write -f ldap/rotate-root"

p "now we will configure a static ldap role for an existing ldap user called hashicorp and set automatic password rotation every 60 minutes."
p "vault write ldap/static-role/hashicorp 
    dn='uid=hashicorp,ou=People,dc=ninjadude,dc=com' 
    username='hashicorp' 
    rotation_period="60m""
vault write ldap/static-role/hashicorp \
    dn='uid=hashicorp,ou=People,dc=ninjadude,dc=com' \
    username='hashicorp' \
    rotation_period="60m"

p "now lets read the new password generated for our ldap user."
pe "vault read ldap/static-cred/hashicorp"

p "the password will be automatically rotated every 60 minutes as configured, we can also force a manual rotation"
pe "vault write -f ldap/rotate-role/hashicorp"

p "now lets read the password again and see the change."
p "vault read ldap/static-cred/hashicorp"

vault read ldap/static-cred/hashicorp > ldap-static.txt
cat ldap-static.txt

p "lets do an ldap query with our new password:"
ldapsearch -H ldap://$(kubectl get svc openldap --output jsonpath='{.status.loadBalancer.ingress[0].hostname}'):389 -b dc=ninjadude,dc=com -D "$(grep -o 'dn[^"]*' ldap-static.txt | cut -c 24-)" -w $(grep -i -w 'password' ldap-static.txt | cut -c 24-)


p "install vault-secrets-operator using helm"
pe "helm repo add hashicorp https://helm.releases.hashicorp.com"
helm search repo hashicorp/vault-secrets-operator --devel > helm.txt
p "helm install --create-namespace --namespace vault-secrets-operator vault-secrets-operator hashicorp/vault-secrets-operator --version $(grep -o 'hashicorp/vault-secrets-operator[^"]*' helm.txt | cut -f2 -d$'\t')"
helm install --create-namespace --namespace vault-secrets-operator vault-secrets-operator hashicorp/vault-secrets-operator --version $(grep -o 'hashicorp/vault-secrets-operator[^"]*' helm.txt | cut -f2 -d$'\t')

pe "kubectl wait deployment vault-secrets-operator-controller-manager -n vault-secrets-operator --for condition=Available=True --timeout=120s"
pe "kubectl wait pod $(kubectl get pods -n vault-secrets-operator -o json | jq .items[].metadata.name | grep vault-secrets-operator-controller | tr -d '"') -n vault-secrets-operator --for condition=Ready --timeout=120s"

p "enable K8S Auth"
pe "vault auth enable kubernetes"
# p "create a secret for vault service account created by the helm deployment"
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
# cat secret.yaml
kubectl apply -f secret.yaml

p "config kuberntes auth backend"
TOKEN_REVIEW_JWT=$(kubectl get secret default -n vault-secrets-operator -o go-template='{{ .data.token }}' | base64 --decode)
KUBE_CA_CERT=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.certificate-authority-data}' | base64 --decode)
KUBE_HOST=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.server}')
ISSUER=$(cat /home/ubuntu/issuer.txt)

# echo $TOKEN_REVIEW_JWT
# echo $KUBE_CA_CERT
# echo $KUBE_HOST
# echo $ISSUER

# clear

# p "vault write auth/kubernetes/config 
#         token_reviewer_jwt="TOKEN_REVIEW_JWT" 
#         kubernetes_host="KUBE_HOST" 
#         kubernetes_ca_cert="KUBE_CA_CERT" 
#         issuer="ISSUER""

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
echo '---
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
    serviceAccount: default' > VaultAuth.yaml
cat VaultAuth.yaml
pe "kubectl apply -f VaultAuth.yaml"

p "Create vault policy to read secrets from defined path:"
p "vault policy write app-read-policy - <<EOF
path "ldap/*" {
  capabilities = ["read"]
}
EOF"

vault policy write app-read-policy - <<EOF
path "ldap/*" {
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

p "now lets create a vault dynamic secret reference. This will sync our secret from vault to k8s secrets and will trigger a rollout on any secret update."

echo "---
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultDynamicSecret
metadata:
  namespace: default
  name: example-dyn
spec:
  vaultAuthRef: example
  mount: ldap
  path: static-cred/hashicorp
  allowStaticCreds: true
  destination:
    create: true
    name: dynamic1
  rolloutRestartTargets:
        -  kind: "Deployment"
           name: "deployment-smb"" > dynamic1.yaml
cat dynamic1.yaml
pe "kubectl apply -f dynamic1.yaml"
pe "kubectl get secrets"
pe "kubectl get secrets dynamic1 -o yaml"

p "install smb csi"
helm repo add csi-driver-smb https://raw.githubusercontent.com/kubernetes-csi/csi-driver-smb/master/charts
helm install csi-driver-smb csi-driver-smb/csi-driver-smb --namespace kube-system --version v1.10.0
kubectl --namespace=kube-system get pods --selector="app.kubernetes.io/name=csi-driver-smb" --watch

p "creating smb server for demo"
echo '---
kind: Service
apiVersion: v1
metadata:
  name: smb-server
  labels:
    app: smb-server
spec:
  type: ClusterIP  # use "LoadBalancer" to get a public ip
  selector:
    app: smb-server
  ports:
    - port: 445
      name: smb-server
---
kind: Deployment
apiVersion: apps/v1
metadata:
  name: smb-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: smb-server
  template:
    metadata:
      name: smb-server
      labels:
        app: smb-server
    spec:
      nodeSelector:
        "kubernetes.io/os": linux
      containers:
        - name: smb-server
          image: andyzhangx/samba:win-fix
          env:
            - name: PERMISSIONS
              value: "0777"
            - name: USERNAME
              valueFrom:
                secretKeyRef:
                  name: dynamic1
                  key: username
            - name: PASSWORD
              valueFrom:
                secretKeyRef:
                  name: dynamic1
                  key: password
          args: ["-u", "$(USERNAME);$(PASSWORD)", "-s", "share;/smbshare/;yes;no;no;all;none", "-p"]
          volumeMounts:
            - mountPath: /smbshare
              name: data-volume
          ports:
            - containerPort: 445
      volumes:
        - name: data-volume
          hostPath:
            path: /home/kubernetes/smbshare-volume  # modify this to specify another path to store smb share data
            type: DirectoryOrCreate' > smb-server.yaml
# cat smb-server.yaml
kubectl create -f smb-server.yaml
pe "kubectl wait deployment smb-server --for condition=Available=True --timeout=120s"
pe "kubectl wait pod $(kubectl get pods -A -o json | jq .items[].metadata.name | grep smb-server | tr -d '"') --for condition=Ready --timeout=120s"


p "creating a storage class"
echo "apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: smb
provisioner: smb.csi.k8s.io
parameters:
  source: "//$(kubectl get svc smb-server -o jsonpath='{.spec.clusterIP}')/share"
  # if csi.storage.k8s.io/provisioner-secret is provided, will create a sub directory
  # with PV name under source
  csi.storage.k8s.io/provisioner-secret-name: "dynamic1"
  csi.storage.k8s.io/provisioner-secret-namespace: "default"
  csi.storage.k8s.io/node-stage-secret-name: "dynamic1"
  csi.storage.k8s.io/node-stage-secret-namespace: "default"
reclaimPolicy: Delete  # available values: Delete, Retain
volumeBindingMode: Immediate
mountOptions:
  - dir_mode=0777
  - file_mode=0777
  - uid=1001
  - gid=1001" > storageclass.yaml
# cat storageclass.yaml
kubectl apply -f storageclass.yaml

p "creating persistant volume"
echo "apiVersion: v1
kind: PersistentVolume
metadata:
  annotations:
    pv.kubernetes.io/provisioned-by: smb.csi.k8s.io
  name: pv-smb
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: smb
  mountOptions:
    - dir_mode=0777
    - file_mode=0777
  csi:
    driver: smb.csi.k8s.io
    readOnly: false
    # volumeHandle format: {smb-server-address}#{sub-dir-name}#{share-name}
    # make sure this value is unique for every share in the cluster
    volumeHandle: smb-server.default.svc.cluster.local/share##
    volumeAttributes:
      source: "//$(kubectl get svc smb-server -o jsonpath='{.spec.clusterIP}')/share"
    nodeStageSecretRef:
      name: dynamic1
      namespace: default" > pv-smb.yaml
# cat pv-smb.yaml
kubectl create -f pv-smb.yaml

p "creating a persistant volume claim"
echo "---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: pvc-smb
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
  volumeName: pv-smb
  storageClassName: smb" > pvc-smb.yaml
# cat pvc-smb.yaml
kubectl create -f pvc-smb.yaml
while [[ $(kubectl get pvc pvc-smb -o 'jsonpath={..status.phase}') != "Bound" ]]; do echo "waiting for PVC status" && sleep 1; done
kubectl get pv,pvc

p "create a deployment that will use our pvc"
echo "---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: nginx
  name: deployment-smb
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
      name: deployment-smb
    spec:
      nodeSelector:
        "kubernetes.io/os": linux
      containers:
        - name: deployment-smb
          image: mcr.microsoft.com/oss/nginx/nginx:1.19.5
          command:
            - "/bin/bash"
            - "-c"
            - set -euo pipefail; while true; do echo $(date) >> /mnt/smb/outfile; sleep 1; done
          volumeMounts:
            - name: smb
              mountPath: "/mnt/smb"
              readOnly: false
      volumes:
        - name: smb
          persistentVolumeClaim:
            claimName: pvc-smb
  strategy:
    rollingUpdate:
      maxSurge: 0
      maxUnavailable: 1
    type: RollingUpdate" > deploy-smb.yaml
cat deploy-smb.yaml
pe "kubectl create -f deploy-smb.yaml"

pe "kubectl wait Deployment deployment-smb --for condition=Available=True --timeout=120s"
pe "kubectl wait pod $(kubectl get pods -A -o json | jq .items[].metadata.name | grep deployment-smb | tr -d '"') --for condition=Ready --timeout=120s"
pe "kubectl exec -it $(kubectl get pods -A -o json | jq .items[].metadata.name | grep deployment-smb | tr -d '"') -- df -h"
pe "kubectl exec -it $(kubectl get pods -A -o json | jq .items[].metadata.name | grep deployment-smb | tr -d '"') -- cat /mnt/smb/outfile"

pe "kubectl get pods,deploy"

p "now we rotate the secret and see what happens"
pe "vault write -f ldap/rotate-role/hashicorp"
pe "kubectl get deploy,pods"

kubectl delete -f deploy-smb.yaml
kubectl rollout restart deployment smb-server
kubectl rollout status deployment smb-server --timeout=120s
kubectl apply -f deploy-smb.yaml

pe "kubectl wait pod $(kubectl get pods -A -o json | jq .items[].metadata.name | grep deployment-smb | tr -d '"') --for condition=Ready --timeout=120s"
pe "kubectl exec -it $(kubectl get pods -A -o json | jq .items[].metadata.name | grep deployment-smb | tr -d '"') -- cat /mnt/smb/outfile"

p "full info and features of vault VSO can be found on the official vault documentations at: https://developer.hashicorp.com/vault/docs/platform/k8s/vso"

p " *** DEMO END *** "

kubectl delete --force -f deploy-smb.yaml
kubectl delete --force -f pvc-smb.yaml
kubectl delete --force -f pv-smb.yaml
kubectl delete --force -f dynamic1.yaml
kubectl delete --force -f VaultAuth.yaml
kubectl delete --force -f VaultConnection.yaml
kubectl delete --force -f secret.yaml
kubectl delete --force -f storageclass.yaml
kubectl delete --force -f smb-server.yaml
helm uninstall -n vault-secrets-operator vault-secrets-operator
helm uninstall csi-driver-smb -n kube-system
kubectl delete --force ns vault-secrets-operator
vault secrets disable ldap
vault secrets disable secrets
vault policy delete app-read-policy
vault auth disable kubernetes
rm *.yaml
rm *.ldif
rm *.txt