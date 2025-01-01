#!/bin/bash

########################
# include the magic
########################
. demo-magic.sh

# hide the evidence
clear
TYPE_SPEED=80
p "Vault KV Secret Engine Demo."

p "Enabling KV Secret Engine in path /secret:"
pe "vault secrets enable --path=secret kv-v2"

p "Writing a secret to KV Secret Engine:"
pe "vault kv put secret/myapp user=giraffe pass=salsa"

p "Reading a secret from KV Secret Engine at path secret/myapp:"
pe "vault kv get secret/myapp"

p "Writing another secret to KV Secret Engine in a differnt path:"
pe "vault kv put secret/mysecret name=xxx key=yyy"

p "Reading the new secret from KV Secret Engine at path secret/mysecret:"
pe "vault kv get secret/mysecret"

p "Create vault policy to allow reading secrets from secret/myapp path:"
p "vault policy write app-read-policy - <<EOF
path "secret/data/myapp" {
  capabilities = ["read"]
}
EOF"

vault policy write app-read-policy - <<EOF
path "secret/data/myapp" {
  capabilities = ["read"]
}
EOF

p "Cretaing a new token and attaching app-read-policy to it"
p "vault token create -policy=app-read-policy"
vault token create -policy=app-read-policy > new_vlt_token.txt
cat new_vlt_token.txt
p "We can see that the new token has app-read-policy attached to it, it means this token can read secret/myapp but not secret/mysecret. lets test that..."
p "logging in to vault with our new token:"
pe "vault login $(grep -ri -m1 -o 'token[^"]*' new_vlt_token.txt | cut -c 22-)"
pe "vault kv get secret/myapp"
pe "vault kv get secret/mysecret"
p "We will now re-write the policy to allow reading all secrets under the secret path"
vault login $(grep -o 'Initial[^"]*' ../../vlt.txt | cut -c 21-)
p "vault policy write app-read-policy - <<EOF
path "secret/data/*" {
  capabilities = ["read"]
}
EOF"

vault policy write app-read-policy - <<EOF
path "secret/data/*" {
  capabilities = ["read"]
}
EOF

pe "vault login $(grep -ri -m1 -o 'token[^"]*' new_vlt_token.txt | cut -c 22-)"
pe "vault kv get secret/myapp"
pe "vault kv get secret/mysecret"

p "full info and features of vault KV secret engine can be found on the official vault documentations at:"
p "https://developer.hashicorp.com/vault/docs/secrets/kv"

p "Demo End."

vault login $(grep -o 'Initial[^"]*' ../../vlt.txt | cut -c 21-)
vault secrets disable secret
vault policy delete app-read-policy
rm new_vlt_token.txt