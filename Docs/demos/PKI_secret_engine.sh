#!/bin/bash

########################
# include the magic
########################
. demo-magic.sh

# hide the evidence
clear

p "Vault PKI Secret Engine Demo."

p "enable vault pki secret engine"
pei "vault secrets enable pki"
p "Tune the pki secrets engine to issue certificates with a maximum time-to-live (TTL) of 87600 hours"
pei "vault secrets tune -max-lease-ttl=87600h pki"
p "Generate the example.com root CA, give it an issuer name, and save its certificate in the file root_2022_ca.crt"
p "vault write -field=certificate pki/root/generate/internal 
     common_name="example.com" 
     issuer_name="root-2022" 
     ttl=87600h > root_2022_ca.crt"
vault write -field=certificate pki/root/generate/internal \
     common_name="example.com" \
     issuer_name="root-2022" \
     ttl=87600h > root_2022_ca.crt

p "list vault pki issuers"
p "vault list pki/issuers/"
vault list pki/issuers/ > pki_issuers.txt
cat pki_issuers.txt

p "read issuer details"
vault read pki/issuer/$(awk 'NR==3' pki_issuers.txt)

p "Create a role for the root CA, creating this role allows for specifying an issuer when necessary
for the purposes of this scenario. This also provides a simple way to transition from one issuer 
to another by referring to it by name."
pei "vault write pki/roles/2022-servers allow_any_name=true"
p "Configure the CA and CRL URLs."
p "vault write pki/config/urls 
     issuing_certificates="$VAULT_ADDR/v1/pki/ca" 
     crl_distribution_points="$VAULT_ADDR/v1/pki/crl""
vault write pki/config/urls \
     issuing_certificates="$VAULT_ADDR/v1/pki/ca" \
     crl_distribution_points="$VAULT_ADDR/v1/pki/crl"

p "full info and features of vault PKI secrets engine can be found on the official vault documentations at:"
p "https://developer.hashicorp.com/vault/docs/secrets/pki"

p "Demo End."

vault secrets disable pki
