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
# pei = print and execute immidiatly 

p "Vault and K8s Demo."
TYPE_SPEED=80
# p "first lets create a k8s secret and mount it into a pod - not using vault"
# p "creating a kubernetes secret called basic-secret"
# pe "kubectl create secret generic basic-secret --from-literal=user=demo_user --from-literal=pass=topsecret"

# p "create a pod and mount basic-secret in it"
# echo 'apiVersion: v1
# kind: Pod
# metadata:
#   name: basic-secret-pod
#   labels:
#     name: secret-test
# spec:
#   volumes:
#   - name: secret-volume
#     secret:
#       secretName: basic-secret
#   containers:
#   - name: secret-test-container
#     image: busybox
#     command: ["sh", "-c", "sleep 4800"]
#     volumeMounts:
#     - name: secret-volume
#       readOnly: true
#       mountPath: "/etc/secret-volume"' > basic_secret_pod.yaml
# cat basic_secret_pod.yaml
# pe "kubectl apply -f basic_secret_pod.yaml"
# pe "kubectl wait pod basic-secret-pod --for condition=Ready --timeout=120s"
# pe "kubectl get pods"
# pe "kubectl exec basic-secret-pod --container secret-test-container -- ls /etc/secret-volume"
# pe "kubectl exec basic-secret-pod --container secret-test-container -- cat /etc/secret-volume/user ; echo"
# pe "kubectl exec basic-secret-pod --container secret-test-container -- cat /etc/secret-volume/pass ; echo"

# pe "kubectl delete --force -f basic_secret_pod.yaml"

p "enable audit to log file"
pe "vault audit enable file file_path=/var/log/vault_audit.log"

p "add label to k8s namespace for demo"
pe "kubectl label namespaces default owner=demo"

p "install vault via Helm"
pe "/usr/local/bin/helm repo add hashicorp https://helm.releases.hashicorp.com"
p "helm install vault hashicorp/vault
    --set "injector.externalVaultAddr=http://$VAULT_IP:8200"
    --set "injector.namespaceSelector.matchLabels.owner=demo""
/usr/local/bin/helm install vault hashicorp/vault \
    --set "injector.externalVaultAddr=http://$VAULT_IP:8200" \
    --set "injector.namespaceSelector.matchLabels.owner=demo"

pe "kubectl wait deployment vault-agent-injector --for condition=Available=True --timeout=120s"
pe "kubectl get pods"

p "enable K8S Auth"
pe "vault auth enable kubernetes"
p "create a secret for vault service account created by the helm deployment"
echo '---
apiVersion: v1
kind: Secret
metadata:
  name: vault
  annotations:
    kubernetes.io/service-account.name: vault
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
  name: vault
  namespace: default' > secret.yaml

cat secret.yaml
pe "kubectl apply -f secret.yaml"


p "config kuberntes auth backend"
TOKEN_REVIEW_JWT=$(kubectl get secret vault -o go-template='{{ .data.token }}' | base64 --decode)
KUBE_CA_CERT=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.certificate-authority-data}' | base64 --decode)
KUBE_HOST=$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[].cluster.server}')
ISSUER=$(cat /home/ubuntu/issuer.txt)

echo $TOKEN_REVIEW_JWT
echo $KUBE_CA_CERT
echo $KUBE_HOST
echo $ISSUER
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


# ****************
# ** KV SECRETS **
# ****************

p "Enabling KV Secret Engine:"
pe "vault secrets enable --path=secret kv-v2"

p "Writing a secret to KV Secret Engine:"
pe "vault kv put secret/myapp user=giraffe pass=salsa"

p "Reading a secret from KV Secret Engine at path secret/myapp:"
pe "vault kv get secret/myapp"

p "create service account for our application"
pe "kubectl create serviceaccount myapp-sa"

p "Create vault policy to read secrets from defined path:"
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


p "create vault role to bound to service account and policy for authentication:"
p "vault write auth/kubernetes/role/myapp-role 
        bound_service_account_names=myapp-sa 
        bound_service_account_namespaces=default 
        policies=app-read-policy 
        ttl=24h"
        
vault write auth/kubernetes/role/myapp-role \
        bound_service_account_names=myapp-sa \
        bound_service_account_namespaces=default \
        policies=app-read-policy \
        ttl=24h



# ***************************
# ** INJECT SECRETS TO POD **
# ***************************
p "create a deployment for myapp"
echo '---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  labels:
    app: vault-agent-injector
spec:
  replicas: 1
  selector:
    matchLabels:
      app: vault-agent-injector
  template:
    metadata:
      annotations:
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/role: "myapp-role"
        vault.hashicorp.com/agent-inject-secret-myapp.txt: "secret/myapp"
        vault.hashicorp.com/template-static-secret-render-interval: "5s"
        vault.hashicorp.com/agent-inject-template-myapp.txt: |
          {{ with secret "secret/data/myapp" -}}
          {{ range $k, $v := .Data.data }}
          export {{ $k }}={{ $v }}
          {{ end }}
          {{- end }}
      labels:
        app: vault-agent-injector
    spec:
      serviceAccountName: myapp-sa
      containers:
      - name: myapp
        image: nginx' > myapp_deploy.yaml
cat myapp_deploy.yaml
kubectl apply -f myapp_deploy.yaml
pe "kubectl wait deployment myapp --for condition=Available=True --timeout=120s"
pe "kubectl get pods"
pe "kubectl exec $(kubectl get pods -A -o json | jq .items[].metadata.name | grep myapp | tr -d '"') --container myapp -- cat /vault/secrets/myapp.txt"
p "Now we change the secret and see what happens..."
pe "vault kv put secret/myapp user=MyNewSecret pass=UpdatePODPlease"
p "Reading the secret from KV Secret Engine at path secret/myapp:"
pe "vault kv get secret/myapp"
pe "kubectl get pods"
wait
pe "kubectl exec $(kubectl get pods -A -o json | jq .items[].metadata.name | grep myapp | tr -d '"') --container myapp -- cat /vault/secrets/myapp.txt"


# ********************************
# *** DATABASE DYNAMIC SECRETS ***
# ********************************
p "Now a Dynamic Secret Example"
p "Enabling Database Secret Engine:"
pe "vault secrets enable database"

p "Configuring Vault to work with mysql Database:"
p 'vault write database/config/vault-lab-db \
  plugin_name=mysql-legacy-database-plugin \
  connection_url="{{username}}:{{password}}@tcp($(cat ../../db-srv.txt))/" \
  root_rotation_statements="SET PASSWORD = PASSWORD('{{password}}')" \
  allowed_roles="mysqlrole" \
  username="root" \
  password="password"'
vault write database/config/vault-lab-db plugin_name=mysql-legacy-database-plugin root_rotation_statements="SET PASSWORD = PASSWORD('{{password}}')" connection_url="{{username}}:{{password}}@tcp($(cat ../../db-srv.txt))/" allowed_roles=mysqlrole username=root password=password

p "Configure a role that maps a name in Vault to an SQL statement to execute to create the database credential:"
p 'vault write database/roles/mysqlrole \
  db_name=vault-lab-db \
  creation_statements="CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}';GRANT SELECT ON *.* TO '{{name}}'@'%';" \
  ttl="1h" \
  max_ttl="24h"'

vault write database/roles/mysqlrole db_name=vault-lab-db creation_statements="CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}';GRANT SELECT ON *.* TO '{{name}}'@'%';" ttl="1h" max_ttl="24h"

p "Rotate the initial db root credentials:"
pe "vault write -force database/rotate-root/vault-lab-db"

p "Read A Dynamic database secret:"
p "vault read database/creds/mysqlrole"
vault read database/creds/mysqlrole -format=json > db.creds
cat db.creds

p "create service account for our DB application"
pe "kubectl create serviceaccount my-db-app-sa"

p "Create vault policy to read secrets from defined path:"
echo 'vault policy write dbapp-policy - <<EOF
path "database/creds/mysqlrole" {
  capabilities = ["read", "create", "update", "delete"]
}
EOF'

vault policy write dbapp-policy - <<EOF
path "database/creds/mysqlrole" {
  capabilities = ["read", "create", "update", "delete"]
}
EOF

p "create vault role to bound to service account and policy for authentication:"
p "vault write auth/kubernetes/role/my_db_app_role 
        bound_service_account_names=my-db-app-sa 
        bound_service_account_namespaces=default 
        policies=dbapp-policy 
        ttl=24h"
        
vault write auth/kubernetes/role/my_db_app_role \
        bound_service_account_names=my-db-app-sa \
        bound_service_account_namespaces=default \
        policies=dbapp-policy \
        ttl=24h

p "create a deployment for myDBapp"
echo '---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-db-app
  labels:
    app: vault-agent-injector
spec:
  replicas: 1
  selector:
    matchLabels:
      app: vault-agent-injector
  template:
    metadata:
      annotations:
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/role: "my_db_app_role"
        vault.hashicorp.com/agent-inject-secret-mydbapp.txt: "database/creds/mysqlrole"
        vault.hashicorp.com/agent-inject-template-mydbapp.txt: |
          {{ with secret "database/creds/mysqlrole" }}
          Dynamic Database Credentials
          user: {{ .Data.username }}
          ID: {{ .Data.password }}
          {{ end }}
      labels:
        app: vault-agent-injector
    spec:
      serviceAccountName: my-db-app-sa
      containers:
      - name: myapp
        image: nginx' > mydbapp_deploy.yaml
cat mydbapp_deploy.yaml
kubectl apply -f mydbapp_deploy.yaml
pe "kubectl wait deployment my-db-app --for condition=Available=True --timeout=120s"
pe "kubectl get pods"
pe "kubectl exec $(kubectl get pods -A -o json | jq .items[].metadata.name | grep my-db | tr -d '"') --container myapp -- cat /vault/secrets/mydbapp.txt"


p "show vault log file"
p "ssh ec2-user@$VAULT_IP -i /home/ubuntu/.ssh/vault_demo.pem -- sudo cat /var/log/vault_audit.log | jq"
ssh ec2-user@$VAULT_IP -i /home/ubuntu/.ssh/vault_demo.pem -- sudo cat /var/log/vault_audit.log | jq

p " *** DEMO END *** "

mysql -h $(cat ../../db-srv.txt | cut -d ':' -f 1) --user=admin --password=password --execute="SET PASSWORD FOR 'root' = PASSWORD('password');"
kubectl delete secret basic-secret
kubectl delete --force pod basic-secret-pod 
kubectl delete --force deploy myapp my-db-app
kubectl delete -f secret.yaml
kubectl delete sa myapp-sa my-db-app-sa
kubectl label namespaces default owner-
rm basic_secret_pod.yaml
rm myapp_deploy.yaml
rm mydbapp_deploy.yaml
rm secret.yaml
vault audit disable file
vault secrets disable secret
vault secrets disable database
vault auth disable kubernetes
/usr/local/bin/helm delete vault