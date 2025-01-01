#!/bin/bash

########################
# include the magic
########################
. demo-magic.sh

# hide the evidence
clear
TYPE_SPEED=80
p "** Vault Advanced Data Protection FPE Demo. **"
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
p "vault write transform/encode/payments value="SSN:123 45 6789" 
    transformation=us-ssn"
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
cat last-four.hcl

pe "vault policy write last-four last-four.hcl"
p "lets create a token with the last-four policy attached and store the token in the env variable LAST_FOUR_TOKEN"
p "LAST_FOUR_TOKEN=$(vault token create -format=json -policy="last-four" | jq -r ".auth.client_token")"
LAST_FOUR_TOKEN=$(vault token create -format=json -policy="last-four" | jq -r ".auth.client_token")

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

p "full info and features of vault Advanced Data Protection can be found on the official vault documentations at:"
p "https://developer.hashicorp.com/vault/tutorials/adp"

p "Demo End."

vault secrets disable transform
rm *.hcl
rm *.txt