#!/bin/bash

########################
# include the magic
########################
. demo-magic.sh

# hide the evidence
clear
TYPE_SPEED=80
p "** Vault Advanced Data Protection Demo - Tokanization. **"
p "** Tokenize Data with Transform Secrets Engine **"
p "There are organizations that care more about the irreversibility of the tokenized data and not so much about preserving the original data format. Therefore, the transform secrets engine's FPE transformation may not meet the governance, risk and compliance (GRC) strategy they are looking for due to the use of reversible cryptography to perform FPE"
p "Transform secrets engine has a data transformation method to tokenize sensitive data stored outside of Vault. Tokenization replaces sensitive data with unique values (tokens) that are unrelated to the original value in any algorithmic sense. Therefore, those tokens cannot risk exposing the plaintext satisfying the PCI-DSS guidance."
p "Characteristics of the tokenization transformation:"
p "Non-reversible identification: Protect data pursuant to requirements for data irreversibility (PCI-DSS, GDPR, etc.)"
p "Integrated Metadata: Supports metadata for identifying data type and purpose"
p "Extreme scale and performance: Support for performantly managing billions of tokens across clouds as well as on-premise"

p "lets enable transform secret engine in vault"
pe "vault secrets enable transform"
p "lets Create a role named mobile-pay with a transformation named credit-card"
pe "vault write transform/role/mobile-pay transformations=credit-card"
p "vault write transform/transformations/tokenization/credit-card
  allowed_roles=mobile-pay
  max_ttl=24h"
vault write transform/transformations/tokenization/credit-card \
  allowed_roles=mobile-pay \
  max_ttl=24h

p "The max_ttl is an optional parameter which allows you to control how long the token should stay valid."

p "Display details about the credit-card transformation. Notice that the type is set to tokenization."
pe "vault read transform/transformations/tokenization/credit-card"
p "Encode a value with the mobile-pay role with some metadata."
p 'vault write transform/encode/mobile-pay value=1111-2222-3333-4444
     transformation=credit-card
     ttl=8h
     metadata="Organization=HashiCorp"
     metadata="Purpose=Travel"
     metadata="Type=AMEX"'
vault write transform/encode/mobile-pay value=1111-2222-3333-4444 \
     transformation=credit-card \
     ttl=8h \
     metadata="Organization=HashiCorp" \
     metadata="Purpose=Travel" \
     metadata="Type=AMEX" > tokenize.txt

p "Retrieve the metadata of the token."
vault write transform/metadata/mobile-pay value=$(grep -o 'encoded_value[^"]*' tokenize.txt | cut -c 18-) transformation=credit-card
p "Validate the token value"
vault write transform/validate/mobile-pay value=$(grep -o 'encoded_value[^"]*' tokenize.txt | cut -c 18-) transformation=credit-card
p "Validate that the credit card number has been tokenized already."
vault write transform/tokenized/mobile-pay value=1111-2222-3333-4444 transformation=credit-card
p "Retrieve the original plaintext credit card value."
vault write transform/decode/mobile-pay transformation=credit-card value=$(grep -o 'encoded_value[^"]*' tokenize.txt | cut -c 18-)
p "If you run the command multiple times, you would notice that it returns a different encoded value every time."
p "In some use cases, you may want to have the same encoded value for a given input so that you can query your database to count the number of entries for a given secret."
p "Key derivation is supported to allow the same key to be used for multiple purposes by deriving a new key based on a user-supplied context value. In this mode, convergent encryption can optionally be supported, which allows the same input values to produce the same ciphertext."

pe "clear"
p "*** Key rotation ***"
p "Rotating keys regularly limits the amount of information produced by a key if that key ever becomes compromised. In this section, you are going to enable automatic key rotation for your tokenization keys."
p "Read the key information for credit-card transformation."
vault read transform/tokenization/keys/credit-card
p "Notice that the latest_version is 1."
p "Rotate the key for credit-card transformation."
pe "vault write -force transform/tokenization/keys/credit-card/rotate"
p "Read the key information again."
pe "vault read transform/tokenization/keys/credit-card"
p "The latest_version is now 2."
p "Now, instead of manually rotating the key, configure the key to be automatically rotated every 90 days to reduce operational overhead."
pe "vault write transform/tokenization/keys/credit-card/config auto_rotate_period=90d"
p "The minimum permitted value for the auto_rotate_period is 1 hour."
p "If the key gets compromised, you can rotate the key using the transform/tokenization/keys/<transformation_name>/rotate, and then set the min_decryption_version to the latest key version so that the older (possibly compromised) key will not be able to decrypt the data."

p "full info and features of vault Advanced Data Protection can be found on the official vault documentations at:"
p "https://developer.hashicorp.com/vault/tutorials/adp"

p "Demo End."

vault secrets disable transform
rm *.txt