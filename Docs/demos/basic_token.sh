#!/bin/bash

########################
# include the magic
########################
. demo-magic.sh

# hide the evidence
clear

p "Vault Basic Token Demo.   -   WIP"

vault policy write my-policy - << EOF
path "secret/*" {
  capabilities = ["read", "create", "update"]
}

path "database/*" {
  capabilities = ["read", "create", "update", "delete"]
}
EOF

p "list vault policies:"
pe "vault policy list"

p "create a vault token and attach the above policy:"
p "vault token create -format=json -policy=my-policy"
vault token create -format=json -policy=my-policy > myToken.txt
cat myToken.txt

p "Demo End."

rm myToken.txt
vault policy delete my-policy
