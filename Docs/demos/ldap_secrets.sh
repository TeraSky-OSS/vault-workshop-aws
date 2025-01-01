#!/bin/bash

########################
# include the magic
########################
. demo-magic.sh

# hide the evidence
clear

p "Vault LDAP secret engine Demo."
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

p "now we will configure a static credentials for an existing ldap user called hashicorp and set automatic password rotation every 24 hours."
p "vault write ldap/static-role/hashicorp 
    dn='uid=hashicorp,ou=People,dc=ninjadude,dc=com' 
    username='hashicorp' 
    rotation_period="24h""
vault write ldap/static-role/hashicorp \
    dn='uid=hashicorp,ou=People,dc=ninjadude,dc=com' \
    username='hashicorp' \
    rotation_period="24h"

p "now lets read the new password generated for our ldap user."
pe "vault read ldap/static-cred/hashicorp"

p "the password will be automatically rotated every 24 hour as configured, we can also force a manual rotation"
pe "vault write -f ldap/rotate-role/hashicorp"

p "now lets read the password again and see the change."
pe "vault read ldap/static-cred/hashicorp"
p "we can also set username and password templating, fine details can be seen in the documentation at: https://developer.hashicorp.com/vault/tutorials/db-credentials/database-secrets#define-a-username-template"


p "now we will set up an ldap dynamic credential."
p "first we need to create a ldif file with our user details"
echo 'dn: cn={{.Username}},ou=People,dc=ninjadude,dc=com
objectClass: person
objectClass: top
cn: ninjadude
sn: {{.Password | utf16le | base64}}
memberOf: cn=dev,ou=groups,dc=ninjadude,dc=com
userPassword: {{.Password}}' > creation.ldif
pe "cat creation.ldif"

echo 'dn: CN={{.Username}},OU=People,DC=ninjadude,DC=com
changetype: delete' > deletion.ldif
pe "cat deletion.ldif"

p "vault write ldap/role/dynamic-role 
  creation_ldif=@creation.ldif 
  deletion_ldif=@deletion.ldif 
  rollback_ldif=@rollback.ldif 
  default_ttl=1h 
  max_ttl=24h"
vault write ldap/role/dynamic-role \
  creation_ldif=@creation.ldif \
  deletion_ldif=@deletion.ldif \
  default_ttl=1h \
  max_ttl=24h

p "lets read the new credentials:"
p "vault read ldap/creds/dynamic-role"
vault read ldap/creds/dynamic-role > ldap_dynamic.txt
cat ldap_dynamic.txt

p "lets do an ldap query with our new dynamic user:"
ldapsearch -H ldap://$(kubectl get svc openldap --output jsonpath='{.status.loadBalancer.ingress[0].hostname}'):389 -b dc=ninjadude,dc=com -D "$(grep -o 'distinguished_names[^"]*' ldap_dynamic.txt | cut -d '[' -f 2 | cut -d ']' -f1)" -w $(grep -o 'password[^"]*' ldap_dynamic.txt | cut -c 24-)

p "now lets revoke our dynamic ldap credential"
pe "vault lease revoke $(grep -o 'lease_id[^"]*' ldap_dynamic.txt | cut -c 24-)"

p "lets try to query ldap again after the revocation :"
ldapsearch -H ldap://$(kubectl get svc openldap --output jsonpath='{.status.loadBalancer.ingress[0].hostname}'):389 -b dc=ninjadude,dc=com -D "$(grep -o 'distinguished_names[^"]*' ldap_dynamic.txt | cut -d '[' -f 2 | cut -d ']' -f1)" -w $(grep -o 'password[^"]*' ldap_dynamic.txt | cut -c 24-)

p "full info and features of vault LDAP secret engine can be found on the official vault documentations at:"
p "https://developer.hashicorp.com/vault/docs/secrets/ldap"

p "Demo End."

vault secrets disable ldap
ldapdelete -H ldap://$(kubectl get svc openldap --output jsonpath='{.status.loadBalancer.ingress[0].hostname}'):389 -D "cn=admin,dc=ninjadude,dc=com" -w $(kubectl get secret openldap -o jsonpath="{.data.LDAP_ADMIN_PASSWORD}" | base64 --decode) uid=hashicorp,ou=People,dc=ninjadude,dc=com
rm ldap_dynamic.txt
rm *.ldif