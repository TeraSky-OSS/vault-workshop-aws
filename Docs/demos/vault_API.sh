#!/bin/bash

########################
# include the magic
########################
. demo-magic.sh

# hide the evidence
clear

p "Vault API Demo."

vault secrets enable --path=secret kv
vault secrets enable --path=more_secrets kv-v2
vault kv put secret/mySecrets user=mySecretUser pass=MySecretPassword!@# creditCardNum=1234-5678-9012-3456
vault kv put more_secrets/mySecrets user=xyz pass=yyy

p "The vault API allows working with and configuring the vault. and is the most feature rich interface."

p "Authentication to vault requires a client token. A user may already have a client token sent to them, Otherwise, a client token can be retrieved using one of the authentication methods"
p "for this demo we will use the initial root token"

p "lets read secrets from path secret/mySecrets using the API"
p 'curl \
-H "X-Vault-Token: hvs.KUasdasdasdfrHjT3jLj1mXzw" \
-X GET \
http://$VAULT_IP:8200/v1/secret/mySecrets'
curl \
-H "X-Vault-Token: $(grep -o 'Initial[^"]*' ../../vlt.txt | cut -c 21-)" \
-X GET \
http://$VAULT_IP:8200/v1/secret/mySecrets > secret.json
cat secret.json | jq .data


p "now lets write a secret using the API we will write the secret to path secret/another_secret" 
p 'curl \
-H "X-Vault-Token: hvs.KUasdasdasdfrHjT3jLj1mXzw" \
-H "Content-Type: application/json" \
-X POST \
-d '{"data":{"value":"secret","anotherValue":"anotherSecret"}}' \
http://$VAULT_IP:8200/v1/secret/another_secret'

curl \
-H "X-Vault-Token: $(grep -o 'Initial[^"]*' ../../vlt.txt | cut -c 21-)" \
-H "Content-Type: application/json" \
-X POST \
-d '{"data":{"value":"secret","anotherValue":"anotherSecret"}}' \
http://$VAULT_IP:8200/v1/secret/another_secret > another_secret.json
cat another_secret.json | jq .data

p "lets list all the secrets available under the secret/ path"
p 'curl \
-H "X-Vault-Token: hvs.KUasdasdasdfrHjT3jLj1mXzw" \
-X LIST http://$VAULT_IP:8200/v1/secret | jq .data.keys'

curl -H "X-Vault-Token: $(grep -o 'Initial[^"]*' ../../vlt.txt | cut -c 21-)" -X LIST http://$VAULT_IP:8200/v1/secret | jq .data.keys

p "we can also config secret path behaviours."
p "for example i want all secrets in path secret/ to only keep maximum of 5 version of the secrets and/or delete the secret after 24 hours"
p "echo '{
  "max_versions": 5,
  "cas_required": false,
  "delete_version_after": "24h"
}' > payload.json"
echo '{
  "max_versions": 5,
  "cas_required": false,
  "delete_version_after": "24h"
}' > payload.json

p 'curl \
    --header "X-Vault-Token: $(grep -o 'Initial[^"]*' ../../vlt.txt | cut -c 21-)" \
    --request POST \
    --data @payload.json \
    http://$VAULT_IP:8200/v1/more_secrets/config'

curl --header "X-Vault-Token: $(grep -o 'Initial[^"]*' ../../vlt.txt | cut -c 21-)" --request POST --data @payload.json http://$VAULT_IP:8200/v1/more_secrets/config

p "now lets read the engine's config"
p "curl \
    --header "X-Vault-Token: hvs.KUasdasdasdfrHjT3jLj1mXzw" \
    http://$VAULT_IP:8200/v1/more_secrets/config | jq"

curl --header "X-Vault-Token: $(grep -o 'Initial[^"]*' ../../vlt.txt | cut -c 21-)" http://$VAULT_IP:8200/v1/more_secrets/config | jq

p "getting help from vault using API"
p "curl \
    -H "X-Vault-Token: hvs.KUasdasdasdfrHjT3jLj1mXzw" \
    http://$VAULT_IP:8200/v1/secret?help=1 | jq"

curl -H "X-Vault-Token: $(grep -o 'Initial[^"]*' ../../vlt.txt | cut -c 21-)" http://$VAULT_IP:8200/v1/secret?help=1 | jq

p "A maximum request size of 32MB is imposed to prevent a denial of service attack with arbitrarily large requests; this can be tuned per listener block in Vault's server configuration file."

p "full info and features of vault's API can be found on the official vault documentations at:"
p "https://developer.hashicorp.com/vault/api-docs"

p "Demo End."

vault secrets disable secret
vault secrets disable more_secrets
rm payload.json
rm another_secret.json
rm secret.json