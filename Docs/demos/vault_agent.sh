#!/bin/bash

########################
# include the magic
########################
. demo-magic.sh

# hide the evidence
clear

p "Vault Agent Demo."

p "creating a simple KV secret to read with the vault agent"
vault secrets enable --path=secret kv
vault kv put secret/mysecrets username=my_secret_user password=my_secret_pass

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

p "creating a vault agent configuration file:"
pe "cat /home/ubuntu/vault-agent.hcl"

p "creating a vault agent template file:"
pe "cat /home/ubuntu/demo.tmpl"

p "running vault agent on our bastion host:"
p "vault agent -config=/home/ubuntu/vault-agent.hcl &"
vault agent -config=/home/ubuntu/vault-agent.hcl &

p "no lets see the rendered file vault agent created for us:"
pe "cat /home/ubuntu/rendered_config.txt"

p "full info and features of vault agent can be found on the official vault documentations at:"
p "https://developer.hashicorp.com/vault/docs/agent"

p "Demo End."

sudo pkill -f vault
vault auth disable approle
vault policy delete my-policy
vault secrets disable secret
rm /home/ubuntu/role_id
rm /home/ubuntu/secret_id
rm /home/ubuntu/rendered_config.txt