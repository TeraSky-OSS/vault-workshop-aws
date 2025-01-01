#!/bin/bash

########################
# include the magic
########################
. demo-magic.sh

# hide the evidence
clear

p "Vault AppRole Demo."

p "lets enable vault's Approle Authentication method"
pe "vault auth enable approle"
p "now lets create a new role called my-role, and specify parameters such as ttl, num of uses etc."
p "vault write auth/approle/role/my-role 
    secret_id_ttl=10m 
    token_num_uses=10 
    token_ttl=20m 
    token_max_ttl=30m 
    secret_id_num_uses=40"
vault write auth/approle/role/my-role \
    secret_id_ttl=10m \
    token_num_uses=10 \
    token_ttl=20m \
    token_max_ttl=30m \
    secret_id_num_uses=40

p "In order to use the approle to login to vault we need its role-id and secret-id"
p "Getting the role-id"
pe "vault read auth/approle/role/my-role/role-id"
p "and finally the secret-id"
p "vault write -f auth/approle/role/my-role/secret-id"
vault write -f auth/approle/role/my-role/secret-id > sec_id.txt
cat sec_id.txt
p "now, using the role-id and secret-id we can login to vault"

p "Demo End."

vault auth disable approle