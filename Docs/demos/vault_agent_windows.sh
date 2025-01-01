#!/bin/bash

########################
# include the magic
########################
. demo-magic.sh

# hide the evidence
clear
TYPE_SPEED=80

p "Vault Agent On Windows Demo."

p "creating a simple KV secret to read with the vault agent"
vault secrets enable --path=secret kv-v2
p "adding new KV secrets to the secret path"
vault kv put secret/mysecret value=my_super_special_secret
vault kv put secret/env1 value=my_env_secret-1
vault kv put secret/env2 value=my_env_secret-2
vault kv put secret/env3 value=my_env_secret-3

p "creating a policy to allow reading the above secret"
vault policy write my-policy - << EOF
path "secret/*" {
  capabilities = ["read", "create", "update"]
}
EOF

p "creating an approle for the vault agent to run with"
p "enable approle auth method:"
pe "vault auth enable approle"
p "create a named role and attach my-policy to it:"
p "vault write auth/approle/role/my-role
    secret_id_ttl=10m
    token_num_uses=10
    token_ttl=20m
    token_max_ttl=30m
    token_policies=my-policy
    secret_id_num_uses=40"

vault write auth/approle/role/my-role token_policies=my-policy

p "get the roleID of the approle:"
p "vault read auth/approle/role/my-role/role-id"

vault read --format=json auth/approle/role/my-role/role-id | jq -r .data.role_id > /home/ubuntu/role_id
cat /home/ubuntu/role_id

p "get the secretID issued for the approle:"
p "vault write -f auth/approle/role/my-role/secret-id"

vault write --format=json -f auth/approle/role/my-role/secret-id | jq -r .data.secret_id > /home/ubuntu/secret_id
cat /home/ubuntu/secret_id

p "now lets configure and run the vault agent on our windows machine with the above role and secret Id's"
p "..."

p "lets change some secrets and see what happens"
pe "vault kv put secret/mysecret value=my_super_NEW_NEW_NEW_special_secret"
pe "vault kv put secret/env1 value=my_NEW_NEW_NEW_env_secret-1"


p "full info and features of vault agent can be found on the official vault documentations at:"
p "https://developer.hashicorp.com/vault/docs/agent"

p "Demo End."

vault auth disable approle
vault policy delete my-policy
vault secrets disable secret