#!/bin/bash

########################
# include the magic
########################
. demo-magic.sh

# hide the evidence
export LDAP_PASS=Zxasqw121212
clear

## NEED TO CONFIGURE OPENLDAP WITH PERMISSIONS

p "Vault LDAP Authentication Method Demo."

echo "dn: uid=hashicorp,ou=People,dc=ninjadude,dc=com
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
uid: hashicorp
sn: xxx
givenName: hashicorp
cn: hashicorp XXX
displayName: hashicorp XXX
uidNumber: 10001
gidNumber: 5001
userPassword: $LDAP_PASS
loginShell: /bin/bash
homeDirectory: /home/hashicorp

echo 'dn: uid=bob,ou=People,dc=ninjadude,dc=com
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
uid: bob
sn: doe
givenName: bob
cn: bob doe
displayName: bob doe
uidNumber: 10002
gidNumber: 5001
userPassword: $LDAP_PASS
loginShell: /bin/bash
homeDirectory: /home/bob

echo 'dn: cn=admins-group,ou=group,dc=ninjadude,dc=com
objectClass: posixGroup
cn: admins-group
gidNumber: 5001

echo 'dn: cn=users-group,ou=group,dc=ninjadude,dc=com
objectClass: posixGroup
cn: users-group
gidNumber: 5002

echo 'dn: cn=admins-group,ou=group,dc=ninjadude,dc=com
changetype: modify
add: memberUid
memberUid: hashicorp

echo 'dn: cn=users-group,ou=group,dc=ninjadude,dc=com
changetype: modify
add: memberUid
memberUid: bob" > populateLDAP.ldif

ldapadd -x -H ldap://$(kubectl get svc openldap --output jsonpath='{.status.loadBalancer.ingress[0].hostname}'):389 -D "cn=admin,dc=ninjadude,dc=com" -w $(kubectl get secret openldap -o jsonpath="{.data.LDAP_ADMIN_PASSWORD}" | base64 --decode) -f populateLDAP.ldif

ldapsearch -x -H ldap://$(kubectl get svc openldap --output jsonpath='{.status.loadBalancer.ingress[0].hostname}'):389 -b dc=ninjadude,dc=com -D "cn=admin,dc=ninjadude,dc=com" -w $(kubectl get secret openldap -o jsonpath="{.data.LDAP_ADMIN_PASSWORD}" | base64 --decode) -s sub "objectclass=*"

pe "vault auth enable ldap"
vault write auth/ldap/config \
    url="ldap://$(kubectl get svc openldap --output jsonpath='{.status.loadBalancer.ingress[0].hostname}'):389" \
    userattr="uid" \
    userdn="ou=People,dc=ninjadude,dc=com" \
    groupdn="ou=group,dc=ninjadude,dc=com" \
    groupattr="cn" \
    binddn="cn=admin,dc=ninjadude,dc=com" \
    bindpass=$(kubectl get secret openldap -o jsonpath="{.data.LDAP_ADMIN_PASSWORD}" | base64 --decode) \
    insecure_tls=true \
    starttls=false

vault secrets enable -path=secret1 kv-v2
vault kv put secret1/mySecret value=secret1
vault secrets enable -path=secret2 kv-v2
vault kv put secret2/mySecret value=secret2
vault secrets enable -path=secret3 kv-v2
vault kv put secret3/mySecret value=secret3

vault policy write secret1 - <<EOF
 path "secret1/*" {
   capabilities = ["create", "read", "update", "patch", "delete", "list"]
 }
EOF

vault policy write secret2 - <<EOF
 path "secret2/*" {
   capabilities = ["create", "read", "update", "patch", "delete", "list"]
 }
EOF

vault policy write secret3 - <<EOF
 path "secret3/*" {
   capabilities = ["create", "read", "update", "patch", "delete", "list"]
 }
EOF

vault write auth/ldap/groups/admins-group policies=secret1,secret2,secret3,admin
vault write auth/ldap/groups/users-group policies=secret1,secret2

p "Trying LDAP Login with user from admin group:"

vault login -method=ldap username=hashicorp
vault secrets list
vault kv get secret1/mySecret
vault kv get secret3/mySecret

p "Trying LDAP Login with user from users group:"

vault login -method=ldap username=bob
vault secrets list
vault kv get secret1/mySecret
vault kv get secret3/mySecret

p "full info and features of vault LDAP Auth method can be found on the official vault documentations at:"
p "https://developer.hashicorp.com/vault/docs/auth/ldap"

p "Demo End."
vault secrets disable secret1
vault secrets disable secret2
vault secrets disable secret3
vault policy delete secret1
vault policy delete secret2
vault policy delete secret3
ldapdelete -H ldap://$(kubectl get svc openldap --output jsonpath='{.status.loadBalancer.ingress[0].hostname}'):389 -D "cn=admin,dc=ninjadude,dc=com" -w $(kubectl get secret openldap -o jsonpath="{.data.LDAP_ADMIN_PASSWORD}" | base64 --decode) uid=hashicorp,ou=People,dc=ninjadude,dc=com
ldapdelete -H ldap://$(kubectl get svc openldap --output jsonpath='{.status.loadBalancer.ingress[0].hostname}'):389 -D "cn=admin,dc=ninjadude,dc=com" -w $(kubectl get secret openldap -o jsonpath="{.data.LDAP_ADMIN_PASSWORD}" | base64 --decode) uid=bob,ou=People,dc=ninjadude,dc=com
ldapdelete -H ldap://$(kubectl get svc openldap --output jsonpath='{.status.loadBalancer.ingress[0].hostname}'):389 -D "cn=admin,dc=ninjadude,dc=com" -w $(kubectl get secret openldap -o jsonpath="{.data.LDAP_ADMIN_PASSWORD}" | base64 --decode) cn=admins-group,ou=group,dc=ninjadude,dc=com
ldapdelete -H ldap://$(kubectl get svc openldap --output jsonpath='{.status.loadBalancer.ingress[0].hostname}'):389 -D "cn=admin,dc=ninjadude,dc=com" -w $(kubectl get secret openldap -o jsonpath="{.data.LDAP_ADMIN_PASSWORD}" | base64 --decode) cn=users-group,ou=group,dc=ninjadude,dc=com
vault auth disable ldap
rm *.ldif