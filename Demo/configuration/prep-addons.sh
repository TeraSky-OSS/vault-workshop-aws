
#######################################
# LDAP
#######################################
OPENLDAP_URL="$OPENLDAP_SERVER:$OPENLDAP_PORT"
OPENLDAP_PORT="1389"
PATH_YAML_LDAP="./yamls/ldap"

# Installing helm chart
helm repo add helm-openldap https://jp-gouin.github.io/helm-openldap/ > /dev/null
helm upgrade -i ldap helm-openldap/openldap-stack-ha -n ldap --create-namespace -f $PATH_YAML_LDAP/ldap-values.yaml > /dev/null
kubectl wait --for=condition=ContainersReady -n ldap pod -l "app.kubernetes.io/component=ldap" --timeout 5m &>/dev/null

sleep 5

# Exposing LDAP
( kubectl port-forward svc/ldap $OPENLDAP_PORT:389 -n ldap > /dev/null 2>&1 & )
# ( kubectl port-forward svc/ldap-phpldapadmin 8080:80 -n ldap > /dev/null 2>&1 & )

sleep 3

# Setup openldap
kubectl create configmap ldap-setup -n default --from-file=setup.ldif=$PATH_YAML_LDAP/setup.ldif > /dev/null 2>&1
kubectl apply -f $PATH_YAML_LDAP/ldap-client.yaml > /dev/null
kubectl wait --for=condition=complete --timeout=600s job/ldap-add-job > /dev/null


#######################################
# Sentinel
#######################################

# Install Sentinel cli
wget -q https://releases.hashicorp.com/sentinel/0.16.1/sentinel_0.16.1_linux_amd64.zip
sudo unzip -o sentinel_0.16.1_linux_amd64.zip -d /usr/local/bin > /dev/null
rm -f sentinel_0.16.1_linux_amd64.zip > /dev/null

#######################################
# Vault Secret Operator
#######################################

# Install Vault Secrets Operator with Helm.
helm repo add hashicorp https://helm.releases.hashicorp.com > /dev/null
helm upgrade --install --create-namespace --namespace vault-secrets-operator vault-secrets-operator hashicorp/vault-secrets-operator > /dev/null
kubectl wait --for=condition=ContainersReady -n vault-secrets-operator pod -l "app.kubernetes.io/name=vault-secrets-operator" --timeout 5m &>/dev/null

