#!/bin/bash

########################
# include the magic
########################
. demo-magic.sh

# hide the evidence
clear
TYPE_SPEED=80
p "** Vault Advanced Data Protection Demo - Data Masking."

p "*** Data Masking ***"
p "Data masking is used to hide sensitive data from those who do not have a clearance to view them. For example, this allows a contractor to test the database environment without having access to the actual sensitive customer information. Data masking has become increasingly important with the enforcement of General Data Protection Regulation (GDPR) introduced in 2018."
p "The following steps demonstrate the use of masking to obscure your customer's phone number since it is personally identifiable information (PII)."
p "lets enable tranform secret engine in vault"
pe "vault secrets enable transform"
p "creating a phone number template with country code"
p 'vault write transform/template/phone-number-tmpl type=regex
    pattern="\+\d{1,2} (\d{3})-(\d{3})-(\d{4})"
    alphabet=builtin/numeric'
vault write transform/template/phone-number-tmpl type=regex \
    pattern="\+\d{1,2} (\d{3})-(\d{3})-(\d{4})" \
    alphabet=builtin/numeric
p "Create a transformation named phone-number"
p "vault write transform/transformations/masking/phone-number
    template=phone-number-tmpl
    masking_character=#
    allowed_roles='*'"
vault write transform/transformations/masking/phone-number \
    template=phone-number-tmpl \
    masking_character=# \
    allowed_roles='*'

p "The type is set to masking and specifies the masking_character value instead of tweak_source. The default masking character is * if you don't specify one."
p "lets add the phone-number transformation to the payments role"
pe "vault write transform/role/payments transformations=phone-number"
p "and Finally, encode a value with the payments role with the phone-number transformation."
p 'vault write transform/encode/payments value="+1 123-345-5678"
    transformation=phone-number'
vault write transform/encode/payments value="+1 123-345-5678" \
    transformation=phone-number

p "this process can also be done as a batch process with multiple values"

# p "*** Batch input processing ***"
# p "When you need to encode more than one secret value, you can send multiple secrets in a request payload as batch_input instead of invoking the API endpoint multiple times to encode secrets individually."
# p "lets Create an API request payload with multiple values."
# tee input-multiple.json <<EOF
# {
#   "batch_input": [
#     {
#       "value": "+1 333-345-5678",
#       "transformation": "phone-number"
#     },
#     {
#       "value": "+1 222-444-5678",
#       "transformation": "phone-number"
#     },
#     {
#       "value": "+1 123-345-5678",
#       "transformation": "phone-number"
#     }
#   ]
# }
# EOF

# p "now lets Encode all the values with the payments role."
# p 'curl --header "X-Vault-Token: hvs.xyz...."
#      --request POST
#      --data @input-multiple.json
#      $VAULT_ADDR/v1/transform/encode/payments | jq ".data"'

# curl --header "X-Vault-Token: $(grep -o 'Initial[^"]*' ../../vlt.txt | cut -c 21-)" \
#      --request POST \
#      --data @input-multiple.json \
#      $VAULT_ADDR/v1/transform/encode/payments | jq ".data"

# p "Example 2: An on-premise database stores corporate phone numbers and your organization decided to migrate the data to another database. You wish to encode those card numbers before storing them in the new database."
# p "first lets Create a request payload with multiple phone numbers."
# tee payload-batch.json <<EOF
# {
#   "batch_input": [
#     { "value": "+1 111-345-5678", "transformation": "phone-number" },
#     { "value": "+1 222-345-5678", "transformation": "phone-number" },
#     { "value": "+1 333-345-5678", "transformation": "phone-number" },
#     { "value": "+1 444-345-5678", "transformation": "phone-number" }
#   ]
# }
# EOF
# p "and now, lets Encode all the values with the payments role."
# p 'curl --header "X-Vault-Token: hvs.xyz...."
#     --request POST
#     --data @payload-batch.json
#     $VAULT_ADDR/v1/transform/encode/payments | jq ".data"'

# curl --header "X-Vault-Token: $(grep -o 'Initial[^"]*' ../../vlt.txt | cut -c 21-)" \
#     --request POST \
#     --data @payload-batch.json \
#     $VAULT_ADDR/v1/transform/encode/payments | jq ".data"

# p "To batch decode these values we First create a request payload with the encoded phone numbers."
# tee payload-batch.json <<EOF
# {
#   "batch_input": [
#     { "value": "7998-7227-5261-3751", "transformation": "card-number" },
#     { "value": "2026-7948-2166-0380", "transformation": "card-number" },
#     { "value": "3979-1805-7116-8137", "transformation": "card-number" },
#     { "value": "0196-8166-5765-0438", "transformation": "card-number" }
#   ]
# }
# EOF
# p "and then, Decode all the values with the payments role."
# p 'curl --header "X-Vault-Token: hvs.xyz...." \
#     --request POST \
#     --data @payload-batch.json \
#     $VAULT_ADDR/v1/transform/decode/payments | jq ".data"'

# curl --header "X-Vault-Token: $(grep -o 'Initial[^"]*' ../../vlt.txt | cut -c 21-)" \
#     --request POST \
#     --data @payload-batch.json \
#     $VAULT_ADDR/v1/transform/decode/payments | jq ".data"

p "full info and features of vault Advanced Data Protection can be found on the official vault documentations at:"
p "https://developer.hashicorp.com/vault/tutorials/adp"

p "Demo End."

vault secrets disable transform