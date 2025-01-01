#!/bin/bash

########################
# include the magic
########################
. demo-magic.sh

# hide the evidence
clear

p "Vault user/pass Authentication Demo."

p "lets enable vault's userpass Authentication method"
pe "vault auth enable userpass"
p "now lets create a new user called demo_user, and specify its password."
p "vault write auth/userpass/users/demo_user 
    password=p@ssword 
    policies=mypolicy"
vault write auth/userpass/users/demo_user password=p@ssword policies=mypolicy

p "now lets login with our new user"
p "vault login -method=userpass 
    username=demo_user 
    password=p@ssword"
vault login -method=userpass username=demo_user     password=p@ssword

p "We can see that we got a new token for this login, and our user has the mypolicy policy attached to it"

p "full info and features of vault userpass authentication method can be found on the official vault documentations at:"
p "https://developer.hashicorp.com/vault/docs/auth/userpass"

p "Demo End."

vault login $(grep -o 'Initial[^"]*' ../../vlt.txt | cut -c 21-)
vault auth disable userpass