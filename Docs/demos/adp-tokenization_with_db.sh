#!/bin/bash

########################
# include the magic
########################
. demo-magic.sh

# hide the evidence
clear
TYPE_SPEED=80
p "** Vault ADP - Tokanization with DB Demo.***WIP*** **"
p "*** Setup external token storage ***"
p "Unlike format preserving encryption (FPE) transformation, tokenization is a stateful procedure to facilitate mapping between tokens and various cryptographic values (one way HMAC of the token, encrypted metadata, etc.) including the encrypted plaintext itself which must be persisted."
p "At scale, this could put a lot of additional load on the Vault's storage backend. To avoid this, you have an option to use external storage to persist data for tokenization transformation."
p "To demonstrate, we will run a MySQL database. Create a new transformation named, "passport" which uses this MySQL as its storage rather than using the Vault's storage backend."
p "the full procedure is described in the documentation."

p "lets enable transform secret engine in vault"
mysql -h $(cat ../../db-srv.txt | cut -d ':' -f 1) --user=root --password=password -e "create database vault"
pe "vault secrets enable transform"
pe "vault write transform/role/global-id transformations=passport"
p 'vault write transform/stores/mysql
   type=sql
   driver=mysql
   supported_transformations=tokenization
   connection_string="{{username}}:{{password}}@tcp($(cat ../../db-srv.txt))/vault?parseTime=true"
   username=root
   password=password'

vault write transform/stores/mysql \
   type=sql \
   driver=mysql \
   supported_transformations=tokenization \
   connection_string="{{username}}:{{password}}@tcp($(cat ../../db-srv.txt):3306)/vault?parseTime=true" \
   username=root \
   password=password

vault write transform/stores/mysql/schema transformation_type=tokenization \
    username=root password=password

vault write transform/transformations/tokenization/passport \
    allowed_roles=global-id stores=mysql

p "connect to the DB and Check to verify that there is no entry."
p 'mysql -h $(cat ../../db-srv.txt | cut -d ':' -f 1) --user=root --password=password -D vault -e "select * from tokens"'

p "now lets encode some test data"
p 'vault write transform/encode/global-id
    transformation=passport
    value="123456789"
    ttl=8h
    metadata="Organization=Terasky_test"
    metadata="Purpose=passport details"'

TOKEN_VALUE=$(vault write transform/encode/global-id \
    transformation=passport \
    value="123456789" \
    ttl=8h \
    metadata="Organization=Terasky_test" \
    metadata="Purpose=passport details" -format=json | jq -r '.data | .encoded_value')
    
p "and, connect to the DB again to verify that the data was added."
pe 'mysql -h $(cat ../../db-srv.txt | cut -d ':' -f 1) --user=root --password=password -D vault -e "select * from tokens"'

p "get token metadat"
pe "vault write transform/metadata/global-id value=$TOKEN_VALUE transformation=passport"
p "valid token value ?"
pe "vault write transform/validate/global-id value=$TOKEN_VALUE transformation=passport"
p "value was already tokenized ?"
pe "vault write transform/tokenized/global-id value=123456789 transformation=passport"
p "retrieve the original value"
pe "vault write transform/decode/global-id transformation=passport value=$TOKEN_VALUE"

p "full info and features of vault Advanced Data Protection can be found on the official vault documentations at:"
p "https://developer.hashicorp.com/vault/tutorials/adp/tokenization?variants=vault-deploy%3Aenterprise"

p "Demo End."

vault secrets disable transform
mysql -h $(cat ../../db-srv.txt | cut -d ':' -f 1) --user=root --password=password -e "drop database vault"