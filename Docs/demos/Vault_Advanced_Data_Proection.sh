#!/bin/bash

########################
# include the magic
########################
. demo-magic.sh

# hide the evidence
clear
TYPE_SPEED=80
p "** Vault Advanced Data Protection Demo. **"
p "The Advanced Data Protection module introduces the Transform secrets engine to handle secure data transformation and tokenization against provided secrets. Transformation methods encompass NIST vetted cryptographic standards such as format-preserving encryption (FPE) via FF3-1 to encode your secrets while maintaining the data format and length. In addition, it can also perform pseudonymous transformations of the data through other means, such as masking."

p "*** Format preserving encryption (FPE) ***"
p "lets enable vault's tranform secret engine"
pe "vault secrets enable transform"

p "now we Create a role named "payments" with "card-number" transformation attached which we will create in the next step"
pe "vault write transform/role/payments transformations=card-number"

p "we will now Create a transformation named "card-number" which will be used to transform credit card numbers. and we will use the built-in template builtin/creditcardnumber to perform format-preserving encryption (FPE)."
p "vault write transform/transformations/fpe/card-number 
    template="builtin/creditcardnumber" 
    tweak_source=internal 
    allowed_roles=payments"
vault write transform/transformations/fpe/card-number \
    template="builtin/creditcardnumber" \
    tweak_source=internal \
    allowed_roles=payments

p "lets list the existing transformations"
pe "vault list transform/transformations/fpe"

p "lets view the details of the newly created card-number transformation"
pe "vault read transform/transformations/fpe/card-number"

p "and finally, let's Encode a value with the payments role."
p "vault write transform/encode/payments value=1111-2222-3333-4444"
vault write transform/encode/payments value=1111-2222-3333-4444 > encoded_card.txt
cat encoded_card.txt
p "as you can see the card number was encoded, while still keeping the credit-card number format."
p "let's Decode the encoded value to get back our real credit card number."
pe "vault write transform/decode/payments value=$(grep -o 'encoded_value[^"]*' encoded_card.txt | cut -c 18-)"

p "now lets create a template for British passport numbers,The number of a British passport is a pattern consisting of a 9-digit numeric value which can be expressed using regular expression as (\d{9}). The parentheses tell Vault to encode all values grouped within; therefore, (\d{9}) will encode the entire passport number."
p "If you want to encode the last 7 digits leaving the first two numbers unchanged, the expression should be \d{2}(\d{7})."

p 'vault write transform/template/uk-passport-tmpl
    type=regex
    pattern="(\d{9})"
    alphabet=builtin/numeric'

vault write transform/template/uk-passport-tmpl \
    type=regex \
    pattern="(\d{9})" \
    alphabet=builtin/numeric

p "Now let's Create a transformation named uk-passport"
p "vault write transform/transformations/fpe/uk-passport
    template=uk-passport-tmpl
    tweak_source=internal
    allowed_roles='*'"

vault write transform/transformations/fpe/uk-passport \
    template=uk-passport-tmpl \
    tweak_source=internal \
    allowed_roles='*'

p "and Update the payments role to also include the uk-passport transformation."
pe "vault write transform/role/payments transformations=card-number,uk-passport"

p "lets Encode a value with the payments role with the uk-passport transformation"
p "vault write transform/encode/payments value="123456789"
    transformation=uk-passport"

vault write transform/encode/payments value="123456789" \
    transformation=uk-passport

p "Remember that you must specify which transformation to use when you send an encode request since the payments role has two transformations associated with it."
pe "clear"
p "*** advanced handling ***"
p "now we are going to create a transformation template which encodes Social Security numbers that may have an optional SSN: or ssn: prefix, and which are optionally separated by dashes or spaces."
p "A USA Security number is a 9-digit number, commonly written using a 3-2-4 digit pattern which can be expressed using the regular expression (\d{3})[- ]?(\d{2})[- ]?(\d{4}). The optional prefix can be expressed using the regular expression (?:SSN[: ]?|ssn[: ]?)?. The use of non-capturing groups tells Vault not to encode the prefix if it is present."
p " vault write transform/template/us-ssn-tmpl
     type=regex
     pattern='(?:SSN[: ]?|ssn[: ]?)?(\d{3})[- ]?(\d{2})[- ]?(\d{4})'
     encode_format='$1-$2-$3'
     alphabet=builtin/numeric"

vault write transform/template/us-ssn-tmpl \
     type=regex \
     pattern='(?:SSN[: ]?|ssn[: ]?)?(\d{3})[- ]?(\d{2})[- ]?(\d{4})' \
     encode_format='$1-$2-$3' \
     alphabet=builtin/numeric

p "Create a transformation named us-ssn with the us-ssn-tmpl template."
p "vault write transform/transformations/fpe/us-ssn
    template=us-ssn-tmpl
    tweak_source=internal
    allowed_roles='*'"

vault write transform/transformations/fpe/us-ssn \
    template=us-ssn-tmpl \
    tweak_source=internal \
    allowed_roles='*'

p "Update the payments role to include the us-ssn transformation."
pe "vault write transform/role/payments transformations=card-number,uk-passport,us-ssn"

p "lets encode values with the payments role using the us-ssn transformation"
pe "vault write transform/encode/payments value="123-45-6789" transformation=us-ssn"
p "now lets Try encoding value that starts with SSN"
p 'vault write transform/encode/payments value="SSN:123 45 6789" 
    transformation=us-ssn'
vault write transform/encode/payments value="SSN:123 45 6789" transformation=us-ssn > ssn.txt
cat ssn.txt
p "Decode the value encoded with the payments role with the us-ssn transformation where the value is set to the encoded_value."
pe "vault write transform/decode/payments value="$(grep -o 'encoded[^"]*' ssn.txt | cut -c 18-)" transformation=us-ssn"
pe "clear"


p "*** Decoding customization ***"
p "we can also create many decode formats, lets recreate the us-ssn template to include 2 decode options."
p " vault write transform/template/us-ssn-tmpl
     type=regex
     pattern='(?:SSN[: ]?|ssn[: ]?)?(\d{3})[- ]?(\d{2})[- ]?(\d{4})'
     encode_format='$1-$2-$3'
     decode_formats=space-separated='$1 $2 $3'
     decode_formats=last-four='*** ** $3'
     alphabet=builtin/numeric"

vault write transform/template/us-ssn-tmpl \
     type=regex \
     pattern='(?:SSN[: ]?|ssn[: ]?)?(\d{3})[- ]?(\d{2})[- ]?(\d{4})' \
     encode_format='$1-$2-$3' \
     decode_formats=space-separated='$1 $2 $3' \
     decode_formats=last-four='*** ** $3' \
     alphabet=builtin/numeric

p "overwrite the us-ssn transformation with the new template."
pe "vault write transform/transformations/fpe/us-ssn
    template=us-ssn-tmpl
    tweak_source=internal
    allowed_roles='*'"

vault write transform/transformations/fpe/us-ssn \
    template=us-ssn-tmpl \
    tweak_source=internal \
    allowed_roles='*'

p "Update the payments role again"
pe "vault write transform/role/payments transformations=card-number,uk-passport,us-ssn"
p "now lets encode value using the us-ssn transformation"
p 'vault write transform/encode/payments value="123-45-6789"
    transformation=us-ssn'

vault write transform/encode/payments value="123-45-6789" transformation=us-ssn > ssn.txt
cat ssn.txt

p "now we will decode the value using the space-separated decoding format."
p "vault write transform/decode/payments/space-separated value="$(grep -o 'encoded[^"]*' ssn.txt | cut -c 18-)"
     transformation=us-ssn"
vault write transform/decode/payments/space-separated value="$(grep -o 'encoded[^"]*' ssn.txt | cut -c 18-)" \
     transformation=us-ssn
p "and again, this time using the last-four decoding format"
p "vault write transform/decode/payments/last-four value="$(grep -o 'encoded[^"]*' ssn.txt | cut -c 18-)"
     transformation=us-ssn"
vault write transform/decode/payments/last-four value="$(grep -o 'encoded[^"]*' ssn.txt | cut -c 18-)" \
     transformation=us-ssn
pe "clear"


p "*** Access control ***"
p "As the decode format is part of the path of the write operation during decoding, Vault policies can be used to control access to them."
p 'with these policies we can
# Allow decoding using any of the decode formats
path "transform/decode/us-ssn/*"
{
    capabilities = ["update"]
}
# Allow decoding using only the last-four decode format
path "transform/decode/us-ssn/last-four"
{
    capabilities = ["update"]
}
# Allow decoding without specifying a decode format
path "transform/decode/us-ssn"
{
    capabilities = ["update"]
}'

p "lets create a token with a policy that will only permit decoding using the last-four decode format."
tee last-four.hcl <<EOF
# Allow decoding using only the last-four decode format
path "transform/decode/payments/last-four"
{
    capabilities = ["update"]
}
EOF

pe "vault policy write last-four last-four.hcl"
p "lets reate a token with the last-four policy attached and store the token in the variable $LAST_FOUR_TOKEN"
pe "LAST_FOUR_TOKEN=$(vault token create -format=json -policy="last-four" | jq -r ".auth.client_token")"

p "Using that token, lts decode values with the payments role, the us-ssn transformation and the last-four decoding format."
p "VAULT_TOKEN=$LAST_FOUR_TOKEN vault write transform/decode/payments/last-four
     value="$(grep -o 'encoded[^"]*' ssn.txt | cut -c 18-)"
     transformation=us-ssn"
VAULT_TOKEN=$LAST_FOUR_TOKEN vault write transform/decode/payments/last-four \
     value="$(grep -o 'encoded[^"]*' ssn.txt | cut -c 18-)" \
     transformation=us-ssn

p "now lets try using the same token to decode with the space-separated decode format, or without specifying a decode format - this will fail."
p "VAULT_TOKEN=$LAST_FOUR_TOKEN vault write transform/decode/payments
     value="$(grep -o 'encoded[^"]*' ssn.txt | cut -c 18-)"
     transformation=us-ssn"
VAULT_TOKEN=$LAST_FOUR_TOKEN vault write transform/decode/payments \
     value="$(grep -o 'encoded[^"]*' ssn.txt | cut -c 18-)" \
     transformation=us-ssn

VAULT_TOKEN=$LAST_FOUR_TOKEN vault write transform/decode/payments/space-separated \
     value="$(grep -o 'encoded[^"]*' ssn.txt | cut -c 18-)" \
     transformation=us-ssn

pe "clear"
p "*** Data Masking ***"
p "Data masking is used to hide sensitive data from those who do not have a clearance to view them. For example, this allows a contractor to test the database environment without having access to the actual sensitive customer information. Data masking has become increasingly important with the enforcement of General Data Protection Regulation (GDPR) introduced in 2018."
p "The following steps demonstrate the use of masking to obscure your customer's phone number since it is personally identifiable information (PII)."
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
pe "vault write transform/role/payments transformations=card-number,uk-passport,phone-number"
p "and Finally, encode a value with the payments role with the phone-number transformation."
p 'vault write transform/encode/payments value="+1 123-345-5678"
    transformation=phone-number'
vault write transform/encode/payments value="+1 123-345-5678" \
    transformation=phone-number

pe "clear"
p "*** Batch input processing ***"
p "When you need to encode more than one secret value, you can send multiple secrets in a request payload as batch_input instead of invoking the API endpoint multiple times to encode secrets individually."
p "Example 1: You received a credit card number, British passport number and a phone number of a customer and wish to transform all these secrets using the payments role."
p "lets Create an API request payload with multiple values, each with the desired transformation."
tee input-multiple.json <<EOF
{
  "batch_input": [
    {
      "value": "1111-1111-1111-1111",
      "transformation": "card-number"
    },
    {
      "value": "123456789",
      "transformation": "uk-passport"
    },
    {
      "value": "+1 123-345-5678",
      "transformation": "phone-number"
    }
  ]
}
EOF

p "now lets Encode all the values with the payments role."
p 'curl --header "X-Vault-Token: $(grep -o 'Initial[^"]*' vlt.txt | cut -c 21-)"
     --request POST
     --data @input-multiple.json
     $VAULT_ADDR/v1/transform/encode/payments | jq ".data"'

curl --header "X-Vault-Token: $(grep -o 'Initial[^"]*' vlt.txt | cut -c 21-)" \
     --request POST \
     --data @input-multiple.json \
     $VAULT_ADDR/v1/transform/encode/payments | jq ".data"

p "Example 2: An on-premise database stores corporate card numbers and your organization decided to migrate the data to another database. You wish to encode those card numbers before storing them in the new database."
p "first lets Create a request payload with multiple card numbers."
tee payload-batch.json <<EOF
{
  "batch_input": [
    { "value": "1111-1111-1111-1111", "transformation": "card-number" },
    { "value": "2222-2222-2222-2222", "transformation": "card-number" },
    { "value": "3333-3333-3333-3333", "transformation": "card-number" },
    { "value": "4444-4444-4444-4444", "transformation": "card-number" }
  ]
}
EOF
p "and now, lets Encode all the values with the payments role."
p 'curl --header "X-Vault-Token: $(grep -o 'Initial[^"]*' ../../vlt.txt | cut -c 21-)"
    --request POST
    --data @payload-batch.json
    $VAULT_ADDR/v1/transform/encode/payments | jq ".data"'

curl --header "X-Vault-Token: $(grep -o 'Initial[^"]*' ../../vlt.txt | cut -c 21-)" \
    --request POST \
    --data @payload-batch.json \
    $VAULT_ADDR/v1/transform/encode/payments | jq ".data"

p "To batch decode these values we First create a request payload with the encoded card numbers."
tee payload-batch.json <<EOF
{
  "batch_input": [
    { "value": "7998-7227-5261-3751", "transformation": "card-number" },
    { "value": "2026-7948-2166-0380", "transformation": "card-number" },
    { "value": "3979-1805-7116-8137", "transformation": "card-number" },
    { "value": "0196-8166-5765-0438", "transformation": "card-number" }
  ]
}
EOF
p "and then, Decode all the values with the payments role."
p 'curl --header "X-Vault-Token: $(grep -o 'Initial[^"]*' ../../vlt.txt | cut -c 21-)" \
    --request POST \
    --data @payload-batch.json \
    $VAULT_ADDR/v1/transform/decode/payments | jq ".data"'

curl --header "X-Vault-Token: $(grep -o 'Initial[^"]*' ../../vlt.txt | cut -c 21-)" \
    --request POST \
    --data @payload-batch.json \
    $VAULT_ADDR/v1/transform/decode/payments | jq ".data"


pe "clear"
p "** Tokenize Data with Transform Secrets Engine **"
p "There are organizations that care more about the irreversibility of the tokenized data and not so much about preserving the original data format. Therefore, the transform secrets engine's FPE transformation may not meet the governance, risk and compliance (GRC) strategy they are looking for due to the use of reversible cryptography to perform FPE"
p "Transform secrets engine has a data transformation method to tokenize sensitive data stored outside of Vault. Tokenization replaces sensitive data with unique values (tokens) that are unrelated to the original value in any algorithmic sense. Therefore, those tokens cannot risk exposing the plaintext satisfying the PCI-DSS guidance."
p "Characteristics of the tokenization transformation:"
p "Non-reversible identification: Protect data pursuant to requirements for data irreversibility (PCI-DSS, GDPR, etc.)"
p "Integrated Metadata: Supports metadata for identifying data type and purpose"
p "Extreme scale and performance: Support for performantly managing billions of tokens across clouds as well as on-premise"

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
     metadata="Organization=Terasky"
     metadata="Purpose=DEMO"
     metadata="Type=AMEX"'
vault write transform/encode/mobile-pay value=1111-2222-3333-4444 \
     transformation=credit-card \
     ttl=8h \
     metadata="Organization=Terasky" \
     metadata="Purpose=DEMO" \
     metadata="Type=AMEX" > tokenize.txt
cat tokenize.txt
p "Retrieve the metadata of the token."
pe "vault write transform/metadata/mobile-pay value=$(grep -o 'encoded_value[^"]*' tokenize.txt | cut -c 18-) transformation=credit-card"
p "Validate the token value"
pe "vault write transform/validate/mobile-pay value=$(grep -o 'encoded_value[^"]*' tokenize.txt | cut -c 18-) transformation=credit-card"
p "Validate that the credit card number has been tokenized already."
pe "vault write transform/tokenized/mobile-pay value=1111-2222-3333-4444 transformation=credit-card"
p "Retrieve the original plaintext credit card value."
pe "vault write transform/decode/mobile-pay transformation=credit-card value=$(grep -o 'encoded_value[^"]*' tokenize.txt | cut -c 18-)"
p "If you run the command multiple times, you would notice that it returns a different encoded value every time."
p "In some use cases, you may want to have the same encoded value for a given input so that you can query your database to count the number of entries for a given secret."
p "Key derivation is supported to allow the same key to be used for multiple purposes by deriving a new key based on a user-supplied context value. In this mode, convergent encryption can optionally be supported, which allows the same input values to produce the same ciphertext."

pe "clear"
p "*** Key rotation ***"
p "Rotating keys regularly limits the amount of information produced by a key if that key ever becomes compromised. In this section, you are going to enable automatic key rotation for your tokenization keys."
p "Read the key information for credit-card transformation."
pe "vault read transform/tokenization/keys/credit-card"
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


pe "clear"
p "*** Setup external token storage ***"
p "Unlike format preserving encryption (FPE) transformation, tokenization is a stateful procedure to facilitate mapping between tokens and various cryptographic values (one way HMAC of the token, encrypted metadata, etc.) including the encrypted plaintext itself which must be persisted."
p "At scale, this could put a lot of additional load on the Vault's storage backend. To avoid this, you have an option to use external storage to persist data for tokenization transformation."
p "To demonstrate, we will run a MySQL database. Create a new transformation named "passport" which uses this MySQL as its storage rather than using the Vault's storage backend."

mysql -h $(cat ../../db-srv.txt | cut -d ':' -f 1) --user=root --password=password -e "create database vault"

pe "vault write transform/role/global-id transformations=passport"

p 'vault write transform/stores/mysql
   type=sql
   driver=mysql
   supported_transformations=tokenization
   connection_string="{{username}}:{{password}}@tcp($(cat ../../db-srv.txt))/vault"
   username=root
   password=password'

vault write transform/stores/mysql \
   type=sql \
   driver=mysql \
   supported_transformations=tokenization \
   connection_string="{{username}}:{{password}}@tcp($(cat ../../db-srv.txt))/vault" \
   username=root \
   password=password

pe "vault write transform/stores/mysql/schema transformation_type=tokenization username=root password=password"
pe "vault write transform/transformations/tokenization/passport allowed_roles=global-id stores=mysql"

p "connect to the DB and Check to verify that there is no entry."
p "mysql -h $(cat ../../db-srv.txt | cut -d ':' -f 1) --user=root --password=password vault -e "select * from tokens""
mysql -h $(cat ../../db-srv.txt | cut -d ':' -f 1) --user=root --password=password vault -e "select * from tokens"

p "now lets encode some test data"
p 'vault write transform/encode/global-id
    transformation=passport
    value="123456789"'
vault write transform/encode/global-id \
    transformation=passport \
    value="123456789" > tokenize2.txt
p "and, connect to the DB again to verify that the data was added."
p "mysql -h $(cat ../../db-srv.txt | cut -d ':' -f 1) --user=root --password=password vault -e "select * from tokens\G""
mysql -h $(cat ../../db-srv.txt | cut -d ':' -f 1) --user=root --password=password vault -e "select * from tokens\G"
# pe "vault write transform/decode/global-id value=$(grep -o 'encoded_value[^"]*' tokenize2.txt | cut -c 18-)"

pe "clear"
p "*** KMIP *** "
p "The OASIS Key Management Interoperability Protocol (KMIP) standard is a widely adopted protocol for handling cryptographic workloads and secrets management for enterprise infrastructure such as databases, network storage, and virtual/physical servers."
p "When an organization has services and applications that need to perform cryptographic operations (e.g.: transparent database encryption, full disk encryption, etc.), it often delegates the key management task to an external provider via KMIP protocol. As a result, your organization may have existing services or applications that implement KMIP or use wrapper clients with libraries/drivers that implement KMIP. This makes it difficult for an organization to adopt the Vault API in place of KMIP."
p "Vault Enterprise has a KMIP secrets engine which allows Vault to act as a KMIP server for clients that retrieve cryptographic keys for encrypting data via KMIP protocol."
p "Vault's KMIP secrets engine manages its own listener to service KMIP requests which operate on KMIP managed objects. Vault policies do not come into play during these KMIP requests. The KMIP secrets engine determines the set of KMIP operations the clients are allowed to perform based on the roles that are applied to the TLS client certificate."
p "This enables the existing systems to continue using the KMIP APIs instead of Vault APIs."
p "refer to the official documentation for more details and examples: https://developer.hashicorp.com/vault/tutorials/adp/kmip-engine"


p "*** Bring your own key (BYOK) ***"
p "Vault Enterprise users can use the BYOK functionality to import an existing encryption key generated outside of Vault, and use it with Transform secrets engine."
p "The target key for import can originate from an HSM or other external source, and must be prepared according to its origin before you can import it."
p "the full procedure is described in the documentation."

p "*** Summary ***"
p "The Transform secrets engine performs secure data transformation and tokenization against the input data. Transformation methods may encompass NIST vetted cryptographic standards such as format-preserving encryption (FPE) via FF3-1, but can also be pseudonymous transformations of the data through other means, such as masking. as seen in This Demo."

p "full info and features of vault Advanced Data Protection can be found on the official vault documentations at:"
p "https://developer.hashicorp.com/vault/tutorials/adp"

p "Demo End."

vault secrets disable transform
mysql -h $(cat ../../db-srv.txt | cut -d ':' -f 1) --user=admin --password=password --execute="SET PASSWORD FOR 'root' = PASSWORD('password');"
mysql -h $(cat ../../db-srv.txt | cut -d ':' -f 1) --user=root --password=password -e "drop database vault"
rm *.hcl
rm *.txt
rm *.json