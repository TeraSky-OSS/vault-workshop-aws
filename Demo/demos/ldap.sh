#!/bin/bash

########################
# include the magic
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
    groupfilter="\(\&\(objectClass=group\)\(member=\{\{\.UserDN\}\}\)\)"
    groupattr="cn"
    userattr="sAMAccountName"
    binddn="$CONNECT_USER"
    bindpass="$CONNECT_USER_PASSWORD"
    starttls=false
    insecure_tls=false"
vault write auth/ldap/config url="$LDAP_SERVER_IP" userdn="DC=dude,DC=com" groupdn="OU=Groups,DC=dude,DC=com" groupfilter="(&(objectClass=group)(member={{.UserDN}}))" groupattr="cn" userattr="sAMAccountName" binddn="vaultcourse@dude.com" bindpass="Aa123456" starttls=false insecure_tls=false

echo ""

p "Testing LDAP Login with Vault"
pe "vault login -method=ldap username=$TEST_USER password=$TEST_USER_PASSWORD"

p ""

# Cleanup
vault login $TOKEN_VAULT > /dev/null
vault auth disable ldap > /dev/null

clear