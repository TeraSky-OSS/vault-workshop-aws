#!/bin/bash

########################
# include the magic
########################
. demo-magic.sh

# hide the evidence
clear
TYPE_SPEED=80

p "Vault AWS Lambda Extension Demo."

p "enable aws auth"
pe "vault auth enable aws"
p "configure aws auth"
p "vault write auth/aws/config/client secret_key=AWS_SECRET_ACCESS_KEY access_key=AWS_ACCESS_KEY_ID"
vault write auth/aws/config/client secret_key=$AWS_SECRET_ACCESS_KEY access_key=$AWS_ACCESS_KEY_ID

p "Set up KV secrets"
p "vault secrets enable --path=lambda kv-v2"
vault secrets enable --path=lambda kv-v2

p "vault kv put lambda/VaultDemo/secret username=MySecretUser password=MySecretPassword"
vault kv put lambda/VaultDemo/secret username=MySecretUser password=MySecretPassword

# Add ACL policy
vault policy write lambda-policy - <<EOF
 path "lambda/*" {
   capabilities = ["read"]
 }
EOF
pe "vault policy read lambda-policy"

#  configure aws auth role and assiogn policy
p "vault write auth/aws/role/$LAMBDA_ROLE_NAME auth_type=iam
    bound_iam_principal_arn=arn:aws:iam::$AWS_ACCOUNT_ID:role/$LAMBDA_ROLE_NAME
    policies=lambda-policy"

vault write auth/aws/role/$LAMBDA_ROLE_NAME auth_type=iam \
    bound_iam_principal_arn=arn:aws:iam::$AWS_ACCOUNT_ID:role/$LAMBDA_ROLE_NAME \
    policies=lambda-policy

p "now we can execute the lambda function and see it in action"
p "aws lambda invoke --function-name $LAMBDA_FUNC_NAME /dev/null --log-type Tail --region $CURRENT_AWS_REGION | jq -r '.LogResult' | base64 --decode"
aws lambda invoke --function-name $LAMBDA_FUNC_NAME /dev/null --log-type Tail --region $CURRENT_AWS_REGION | jq -r '.LogResult' | base64 --decode

p "full info and features of vault AWS Lambda Extension can be found on the official vault documentations at:"
p "https://developer.hashicorp.com/vault/tutorials/app-integration/aws-lambda"

p "Demo End."

vault policy delete lambda-policy
vault secrets disable lambda
vault auth disable aws