#!/bin/bash

########################
# include the magic
########################
. demo-magic.sh

# hide the evidence
clear

p "Vault Basic Policy Demo."



p "lets take a look at the default policy permissions:"
pe "vault policy read default"

p "adding a new policy called my-policy:"
p "vault policy write my-policy - << EOF
path "secret/*" {
  capabilities = ["read", "create", "update"]
}

path "database/*" {
  capabilities = ["read", "create", "update", "delete"]
}
EOF"

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

vault secrets disable database
vault policy delete my-policy