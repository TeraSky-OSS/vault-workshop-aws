#!/bin/bash

########################
# include the magic
########################
. demo-magic.sh

# hide the evidence
clear

p "Vault Namespace Demo."

p "lets list all vault namespaces:"
pe "vault namespace list"
p "We will now create a new namespace called Vault_Demo."
pe "vault namespace create Vault_Demo/"
p "and another one called DEV."
pe "vault namespace create DEV/"
p "lets list all vault namespaces again:"
pe "vault namespace list"
p "We will now create a new namespace called PROD with some metadata Values."
pe "vault namespace create -custom-metadata=Environment=Production PROD/"
p "We can also patch an existing namespace and add/remove metadata Values."
pe "vault namespace patch -custom-metadata=Environment=Development DEV/"
p "We can also lock the API for a specific namespace."
p "vault namespace lock Vault_Demo/"
vault namespace lock Vault_Demo/ > vault_unlock.txt
cat vault_unlock.txt
p "and unlock a namespace using the unlock_key"
pe "vault namespace unlock -unlock-key $(grep -o 'unlock_key[^"]*' vault_unlock.txt | cut -c 15-) Vault_Demo/"
p "and finally lets delete a namespace"
pe "vault namespace delete Vault_Demo/"

p "full info and features of vault namespaces can be found on the official vault documentations at:"
p "https://developer.hashicorp.com/vault/docs/enterprise/namespaces"

p "Demo End."

vault namespace delete DEV/
vault namespace delete PROD/