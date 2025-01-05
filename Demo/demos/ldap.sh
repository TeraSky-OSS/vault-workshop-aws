#!/bin/bash

########################
# Import magic
########################
. ./configuration/demo-magic.sh
. ./configuration/helper_functions.sh
. ./configuration/env.sh
########################
clear

LDAP_SERVER_IP="ldap://172.16.205.75"

CONNECT_USER="vaultcourse@dude.com"
CONNECT_USER_PASSWORD="Aa123456"

TEST_USER="shlomih"
TEST_USER_PASSWORD="Aa123456"
PATH_YAML_LDAP="$YAML_PATH/ldap"

OPENLDAP_SERVER="ldap://127.0.0.1"
OPENLDAP_PORT="1389"
OPENLDAP_URL="$OPENLDAP_SERVER:$OPENLDAP_PORT"
# Start demo here

caption "LDAP Auth"
echo ""

p "Configuring LDAP Authentication in Vault"
pe "vault auth enable ldap"

echo ""

p "vault write auth/ldap/config
    url="$LDAP_SERVER_IP"
    userdn="DC=dude,DC=com"
    groupdn="OU=Groups,DC=dude,DC=com"
    groupfilter=\"(&(objectClass=group)(member={{.UserDN\}}))\"
    groupattr="cn"
    userattr="sAMAccountName"
    binddn="$CONNECT_USER"
    bindpass="$CONNECT_USER_PASSWORD"
    starttls=false
    insecure_tls=false"
vault write auth/ldap/config url="$LDAP_SERVER_IP" userdn="DC=dude,DC=com" groupdn="OU=Groups,DC=dude,DC=com" groupfilter="(&(objectClass=group)(member={{.UserDN}}))" groupattr="cn" userattr="sAMAccountName" binddn="$CONNECT_USER" bindpass="$CONNECT_USER_PASSWORD" starttls=false insecure_tls=false

echo ""

p "Testing LDAP Login with Vault"
p "vault login -method=ldap username=$TEST_USER password=$TEST_USER_PASSWORD"
vault login -method=ldap username=$TEST_USER password=$TEST_USER_PASSWORD 2> /dev/null

echo ""
p "LDAP Auth - Done"
echo ""

# --------------------
vault login $TOKEN_VAULT > /dev/null

caption "LDAP Dynamic Secret Engine"
echo ""

p "Setting everything up..."
helm repo add helm-openldap https://jp-gouin.github.io/helm-openldap/ > /dev/null
helm upgrade -i ldap helm-openldap/openldap-stack-ha -n ldap --create-namespace -f $PATH_YAML_LDAP/ldap-values.yaml > /dev/null
OPENLDAP_ADMIN_PASSWORD=$(kubectl get secret ldap -n ldap -o jsonpath="{.data.LDAP_ADMIN_PASSWORD}" | base64 --decode)
kubectl wait --for=condition=ContainersReady -n ldap pod -l "app.kubernetes.io/component=ldap" --timeout 5m &>/dev/null

sleep 5

# Exposing LDAP
( kubectl port-forward svc/ldap $OPENLDAP_PORT:389 -n ldap > /dev/null 2>&1 & )
( kubectl port-forward svc/ldap-phpldapadmin 8080:80 -n ldap > /dev/null 2>&1 & )

sleep 3

# Setup openldap
ldapadd -x -H ldap://127.0.0.1:$OPENLDAP_PORT -D "cn=admin,dc=example,dc=org" -w "Not@SecurePassw0rd" -f $PATH_YAML_LDAP/setup.ldif #&>/dev/null

# p "Connecting to LDAP server with root user"
# pe "ldapsearch -x -H $OPENLDAP_URL -b dc=example,dc=org -D "cn=admin,dc=example,dc=org" -w $OPENLDAP_ADMIN_PASSWORD"

p "Enable LDAP Secrets Engine"
pe "vault secrets enable ldap"

p "Configure LDAP Configuration"
p "vault write ldap/config
  binddn="cn=admin,dc=example,dc=org"
  bindpass="Not@SecurePassw0rd"
  url="ldap://ldap.ldap.svc.cluster.local" "
vault write ldap/config binddn="cn=admin,dc=example,dc=org" bindpass="Not@SecurePassw0rd" url="ldap://ldap.ldap.svc.cluster.local"

# p "Rotate the root password so only Vault knows the credentials:"
# pe "vault write -f ldap/rotate-root"

# p "Lets try logging in again with root user"
# pe "ldapsearch -x -H $OPENLDAP_URL -b dc=example,dc=org -D "cn=admin,dc=example,dc=org" -w $OPENLDAP_ADMIN_PASSWORD"
# p "As we can see it failed since we rotated his password"

p "Configuring dynamic credentials"
p "vault write ldap/role/dynamic-role
  creation_ldif=@\$PATH_YAML_LDAP/creation.ldif
  deletion_ldif=@\$PATH_YAML_LDAP/deletion.ldif
  default_ttl=1h
  max_ttl=24h"
vault write ldap/role/dynamic-role creation_ldif=@$PATH_YAML_LDAP/creation.ldif deletion_ldif=@$PATH_YAML_LDAP/deletion.ldif default_ttl=1h max_ttl=24h

echo ""

p "Now lets generate dynamic credentials"
p "vault read -format=json ldap/creds/dynamic-role"
OUTPUT=$(vault read -format=json ldap/creds/dynamic-role)
echo $OUTPUT | jq
USERNAME=$(echo $OUTPUT | jq -r '.data.username')
PASSWORD=$(echo $OUTPUT | jq -r '.data.password')
LEASE_ID=$(echo $OUTPUT | jq -r '.lease_id')

p "Login with the dynamic credenitals"
pe "ldapsearch -x -H $OPENLDAP_URL -b dc=example,dc=org -D "cn=$USERNAME,ou=users,dc=example,dc=org" -w $PASSWORD"

p "Revoke our dynamic ldap credentials"
pe "vault lease revoke $LEASE_ID"

p "Lets try again logining with the same dynamic credenitals and see that they are revoked."
pe "ldapsearch -x -H $OPENLDAP_URL -b dc=example,dc=org -D "cn=$USERNAME,ou=users,dc=example,dc=org" -w $PASSWORD"

echo ""
caption "LDAP Dynamic Secret Engine - Done"

echo ""

# Cleanup
vault auth disable ldap > /dev/null
vault secrets disable ldap > /dev/null
helm uninstall ldap -n ldap > /dev/null
kubectl delete pvc -n ldap --all > /dev/null

clear
