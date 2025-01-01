#!/bin/bash

########################
# include the magic
########################
. demo-magic.sh

# hide the evidence
clear

p "Vault PKI Secret Engine intermediate CA Demo."
vault secrets enable pki
vault secrets tune -max-lease-ttl=87600h pki
vault write -field=certificate pki/root/generate/internal \
     common_name="example.com" \
     issuer_name="root-2022" \
     ttl=87600h > root_2022_ca.crt
vault list pki/issuers/ > pki_issuers.txt
vault write pki/roles/2022-servers allow_any_name=true
vault write pki/config/urls \
     issuing_certificates="$VAULT_ADDR/v1/pki/ca" \
     crl_distribution_points="$VAULT_ADDR/v1/pki/crl"

p "We will be using our vault as the root CA for this demo"

p "Generate intermediate CA"
pe "vault secrets enable -path=pki_int pki"
pe "vault secrets tune -max-lease-ttl=43800h pki_int"
p "Execute the following command to generate an intermediate and save the CSR as pki_intermediate.csr"
p "vault write -format=json pki_int/intermediate/generate/internal 
     common_name="example.com Intermediate Authority" 
     issuer_name="example-dot-com-intermediate" 
     | jq -r '.data.csr' > pki_intermediate.csr"
vault write -format=json pki_int/intermediate/generate/internal \
     common_name="example.com Intermediate Authority" \
     issuer_name="example-dot-com-intermediate" \
     | jq -r '.data.csr' > pki_intermediate.csr
pe "cat pki_intermediate.csr"

p "sign intermediate cert with root ca"
p "vault write -format=json pki/root/sign-intermediate 
     issuer_ref="root-2022" 
     csr=@pki_intermediate.csr 
     format=pem_bundle ttl="43800h" 
     | jq -r '.data.certificate' > intermediate.cert.pem"
vault write -format=json pki/root/sign-intermediate \
     issuer_ref="root-2022" \
     csr=@pki_intermediate.csr \
     format=pem_bundle ttl="43800h" \
     | jq -r '.data.certificate' > intermediate.cert.pem
p "Once the CSR is signed and the root CA returns a certificate, it can be imported back into Vault."
pe "vault write pki_int/intermediate/set-signed certificate=@intermediate.cert.pem"

p "create a role"
p "vault write pki_int/roles/example-dot-com 
     issuer_ref="$(vault read -field=default pki_int/config/issuers)" 
     allowed_domains="example.com" 
     allow_subdomains=true 
     max_ttl="720h""
vault write pki_int/roles/example-dot-com \
     issuer_ref="$(vault read -field=default pki_int/config/issuers)" \
     allowed_domains="example.com" \
     allow_subdomains=true \
     max_ttl="720h"

p "Request a certificate"
pe "vault write pki_int/issue/example-dot-com common_name="test.example.com" ttl="24h""
vault write pki_int/issue/example-dot-com common_name="test.example.com" ttl="24h" > my_cert.txt
cat my_cert.txt
p "Revoke a certificate"
pe "vault write pki_int/revoke serial_number=$(grep -o 'serial_[^"]*' my_cert.txt | cut -c 21-)"

p "full info and features of vault PKI secrets engine can be found on the official vault documentations at:"
p "https://developer.hashicorp.com/vault/docs/secrets/pki"

p "Demo End."

vault secrets disable pki_int
rm root_2022_ca.crt
rm pki_issuers.txt
rm pki_intermediate.csr
rm intermediate.cert.pem
rm my_cert.txt
