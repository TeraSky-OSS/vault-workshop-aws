#!/bin/bash

########################
# include the magic
########################
. demo-magic.sh

# hide the evidence
clear
TYPE_SPEED=80
p "Vault Transit Secret engine Demo."

p "Enabling Transit Secret Engine in vault:"
pe "vault secrets enable transit"

p "create a named encryption key:"
pe "vault write -f transit/keys/my-key"

p "Encrypt a secret using Transit Secret Engine:"
p "we will encrypt the string \"my secret data\", we have to base64 encode it before sending to vault."
p "vault write -format=json transit/encrypt/my-key plaintext=$(echo "my secret data" | base64)"
vault write -format=json transit/encrypt/my-key plaintext=$(echo "my secret data" | base64) > transit.json
cat transit.json

p "Decrypt a secret using Transit Secret Engine:"
pe "vault write transit/decrypt/my-key ciphertext=$(cat transit.json | jq -r .data.ciphertext)"

p "We got our secret in base64, now we do a base64 decrypt..."
pe "base64 --decode <<< $(vault write --format=json transit/decrypt/my-key ciphertext=$(cat transit.json | jq -r .data.ciphertext) | jq -r .data.plaintext)"

p "now, let's Rotate the underlying encryption key. This will generate a new encryption key and add it to the keyring for the named key"
pe "vault write -f transit/keys/my-key/rotate"
p "Future encryptions will use this new key. Old data can still be decrypted due to the use of a key ring."

p "Upgrade already-encrypted data to a new key. Vault will decrypt the value using the appropriate key in the keyring and then encrypted the resulting plaintext with the newest key in the keyring."
pe "vault write transit/rewrap/my-key ciphertext=$(cat transit.json | jq -r .data.ciphertext)"
p "This process does not reveal the plaintext data. As such, a Vault policy could grant almost an untrusted process the ability to "rewrap" encrypted data, since the process would not be able to get access to the plaintext data."
pe "clear"


p "*** batch processing ***"
p "first lets create the batch payload."
p 'All plaintext data must be base64-encoded. The reason for this requirement is that Vault does not require that the plaintext is "text".'
p "It could be a binary file such as a PDF or image. The easiest safe transport mechanism for this data as part of a JSON payload is to base64-encode it."

p "perform batch encrypt using rest-api"
p 'curl --location "$VAULT_ADDR/v1/transit/encrypt/my-key?batch_input=null" 
--header "X-Vault-Token: xyz......" 
--header "Content-Type: application/json" 
--data {
    "batch_input":[
        {
            "plaintext": "aGVsbG8gd29ybGQ="
        },
        {
            "plaintext": "SGVsbG8gV29ybGQ="
        }
    ]
}"'

curl --location "$VAULT_ADDR/v1/transit/encrypt/my-key?batch_input=null" \
--header "X-Vault-Token: $(grep -o 'Initial[^"]*' ../../vlt.txt | cut -c 21-)" \
--header 'Content-Type: application/json' \
--data '{
    "batch_input":[
        {
            "plaintext": "aGVsbG8gd29ybGQ="
        },
        {
            "plaintext": "SGVsbG8gV29ybGQ="
        }
    ]
}' > batch-encrypt.json

cat batch-encrypt.json  | jq


p "perform batch decrypt using rest-api"
p 'curl --location "$VAULT_ADDR/v1/transit/decrypt/my-key?batch_input=null" 
--header "X-Vault-Token: xyz......" 
--header Content-Type: application/json 
--data "{\"batch_input\":$(cat batch-encrypt.json | jq .data.batch_results)}"'

curl --location "$VAULT_ADDR/v1/transit/decrypt/my-key?batch_input=null" \
--header "X-Vault-Token: $(grep -o 'Initial[^"]*' ../../vlt.txt | cut -c 21-)" \
--header 'Content-Type: application/json' \
--data "{\"batch_input\":$(cat batch-encrypt.json | jq .data.batch_results)}" | jq

pe "clear"

p "full info and features of vault Transit Secret engine can be found on the official vault documentations at:"
p "https://developer.hashicorp.com/vault/docs/secrets/transit"

p "Demo End."
vault secrets disable transit
rm *.json