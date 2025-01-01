#!/bin/bash

########################
# include the magic
########################
. ./configuration/demo-magic.sh
. ./configuration/helper_functions.sh
. ./configuration/env.sh
########################
clear

# Start demo here

caption "PKI Secret Engine"
echo ""

########################
# Step 1
caption "Step 1: generate root CA"
echo ""

p "Enable the PKI secrets engine in Vault"
pe "vault secrets enable pki"

echo ""

p "Set the PKI engine to issue certificates with a maximum TTL of 10 years"
pe "vault secrets tune -max-lease-ttl=87600h pki"

echo ""

p "Generate the example.com root CA, assign an issuer name, and save the certificate to a file"
pe "vault write -field=certificate pki/root/generate/internal common_name="example.com" issuer_name="root-2024" ttl=87600h > root_2024_ca.crt"

echo ""

p "List all issuers in the Vault PKI engine"
pe "vault list pki/issuers/"

echo ""

p "View details of the newly created issuer"
PKI_ISSUER_KEY=$(vault list -format=json pki/issuers/ | jq -r '.[]')
pe "vault read pki/issuer/$PKI_ISSUER_KEY | tail -n 6"

echo ""

p "Create a role for the root CA to allow specifying an issuer and simplify future transitions"
pe "vault write pki/roles/2024-servers allow_any_name=true"

echo ""

p "Set the URLs for issuing certificates and CRL distribution"
pe "vault write pki/config/urls issuing_certificates="$VAULT_ADDR/v1/pki/ca" crl_distribution_points="$VAULT_ADDR/v1/pki/crl""

p ""

########################
# Step 2
caption "Step 2: generate intermediate CA"
echo ""

p "Enable the pki secrets engine at pki_int."
pe "vault secrets enable -path=pki_int pki"

echo ""

p "Set the max TTL for pki_int to 5 years."
pe "vault secrets tune -max-lease-ttl=43800h pki_int"

echo ""

p "Generate an intermediate CA and save the CSR to pki_intermediate.csr."
pe "vault write -format=json pki_int/intermediate/generate/internal common_name='example.com Intermediate Authority' issuer_name='example-dot-com-intermediate' | jq -r '.data.csr' > pki_intermediate.csr"

echo ""

p "Sign the intermediate CA with the root CA and save it as intermediate.cert.pem."
pe "vault write -format=json pki/root/sign-intermediate issuer_ref='root-2024' csr=@pki_intermediate.csr format=pem_bundle ttl='43800h' | jq -r '.data.certificate' > intermediate.cert.pem"

echo ""

p "Import the signed intermediate certificate into Vault."
pe "vault write pki_int/intermediate/set-signed certificate=@intermediate.cert.pem"

p ""

########################
# Step 3
caption "Step 3: create a role"
echo ""

p "Create a role to issue certs for example.com and subdomains."
VAULT_ISSUER_REF=$(vault read -field=default pki_int/config/issuers)
pe "vault write pki_int/roles/example-dot-com issuer_ref="$VAULT_ISSUER_REF" allowed_domains="example.com" allow_subdomains=true max_ttl="720h""

p ""

########################
# Step 4
caption "Step 4: request certificates"
echo ""

p "Request a certificate for test.example.com."
pe "vault write pki_int/issue/example-dot-com common_name='test.example.com' ttl='24h'"

p ""

########################
# Step 5
caption "Step 5: remove expired certificates"
echo ""

p "Clean up revoked and expired certificates."
pe "vault write pki_int/tidy tidy_cert_store=true tidy_revoked_certs=true"

p ""

########################
# Step 6
caption "Step 6: rotate root CA"
echo ""

p "Rotate the root CA and create a new one."
pe "vault write pki/root/rotate/internal common_name='example.com' issuer_name='root-2024'" ##$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$

echo ""

p "List all issuers to confirm the new root CA."
pe "vault list pki/issuers"

echo ""

p "Create a role for the new root CA to issue certificates."
pe "vault write pki/roles/2024-servers allow_any_name=true"

p ""


# Cleanup
rm -f root_2024_ca.crt intermediate.cert.pem pki_intermediate.csr > /dev/null
vault delete pki/roles/2024-servers > /dev/null
vault delete pki_int/roles/example-dot-com > /dev/null
vault secrets disable pki > /dev/null
vault secrets disable pki_int > /dev/null

clear