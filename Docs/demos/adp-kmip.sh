#!/bin/bash

# https://developer.hashicorp.com/vault/tutorials/adp/kmip-engine?variants=vault-deploy%3Aenterprise
# https://developer.hashicorp.com/vault/tutorials/adp/kmip-engine

########################
# include the magic
########################
. demo-magic.sh

# hide the evidence
clear

p "Vault KMIP secret engine Demo. - WIP"

# helm install enterprise-operator mongodb/enterprise-operator
# helm install mongodb mongodb/enterprise-database  #--namespace mongodb [--create-namespace]


export TEMP_DIR=$(pwd)
export VAULT_TOKEN=$(grep -o 'Initial[^"]*' ../../vlt.txt | cut -c 21-)

vault login $VAULT_TOKEN

p "write policy for KMIP"
vault policy write kmip - <<EOF
# Work with kmip secrets engine
path "kmip/*" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}

# Enable secrets engine
path "sys/mounts/*" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}

# List enabled secrets engine
path "sys/mounts" {
  capabilities = [ "read", "list" ]
}
EOF

pe "vault policy read kmip"

p "lets enable the KMIP engine in Vault"
pe "vault secrets enable kmip"

p "generating an Elliptic Curve Certificate"
p "vault write kmip/config
     listen_addrs=0.0.0.0:5696
     server_hostnames=$VAULT_ADDR"

vault write kmip/config \
     listen_addrs=0.0.0.0:5696 \
     server_hostnames=$VAULT_ADDR

p "generating RSA Certificate"
p 'vault write kmip/config
      listen_addrs=0.0.0.0:5696
      tls_ca_key_type="rsa"
      tls_ca_key_bits=2048'

vault write kmip/config \
      listen_addrs=0.0.0.0:5696 \
      tls_ca_key_type="rsa" \
      tls_ca_key_bits=2048

p "vault read kmip/ca -format=json | jq -r '.data | .ca_pem'"
vault read kmip/ca -format=json | jq -r '.data | .ca_pem' >> vault-ca.pem && cat vault-ca.pem

pe "vault write -f kmip/scope/finance"

pe "vault list kmip/scope"

pe "vault write kmip/scope/finance/role/accounting operation_all=true"

pe "vault list kmip/scope/finance/role"
pe "vault read kmip/scope/finance/role/accounting"

p "vault write -format=json
    kmip/scope/finance/role/accounting/credential/generate
    format=pem"

vault write -format=json \
    kmip/scope/finance/role/accounting/credential/generate \
    format=pem > credential.json && cat credential.json

pe "jq -r .data.certificate < credential.json > cert.pem"
pe "jq -r .data.private_key < credential.json > key.pem"

pe "vault list kmip/scope/finance/role/accounting/credential"

p "vault read kmip/scope/finance/role/accounting/credential/lookup
        serial_number=$(cat credential.json | jq -r '.data | .serial_number')"

vault read kmip/scope/finance/role/accounting/credential/lookup \
        serial_number=$(cat credential.json | jq -r '.data | .serial_number')

pe "cat cert.pem key.pem > client.pem"

#CONFIGURE MONGO-DB TO USE VAULT KMIP
p "after entering the mongoDB container run this command:"
p "mongod --dbpath /TEMP_DIR --enableEncryption --kmipServerName \$KMIP_ADDR --kmipPort 5696 --kmipServerCAFile /TEMP_DIR/vault-ca.pem --kmipClientCertificateFile /TEMP_DIR/client.pem"
p "and then type exit to resume demo"

kubectl exec -it $(kubectl get pods --no-headers -o custom-columns=":metadata.name" | grep mongo) -- bash

p "Revoking a client certificate"
p 'vault write kmip/scope/finance/role/accounting/credential/revoke
        serial_number=$(cat credential.json | jq -r '.data | .serial_number')'

vault write kmip/scope/finance/role/accounting/credential/revoke \
        serial_number=$(cat credential.json | jq -r '.data | .serial_number')

pe "vault list kmip/scope/finance/role/accounting/credential"

p "Manage KMIP roles"
p "vault write kmip/scope/finance/role/accounting
        operation_activate=true
        operation_create=true
        operation_get=true"

vault write kmip/scope/finance/role/accounting \
        operation_activate=true \
        operation_create=true \
        operation_get=true

pe "vault read kmip/scope/finance/role/accounting"
pe "vault delete kmip/scope/finance/role/accounting"

pe "vault delete kmip/scope/finance force=true"

pe "openssl x509 -in cert.pem -text -noout"


p "full info and features of vault SSH secret engine can be found on the official vault documentations at:"
p "https://developer.hashicorp.com/vault/tutorials/adp/kmip-engine"

p "Demo End."
vault secrets disable kmip
vault policy delete kmip
rm *.pem