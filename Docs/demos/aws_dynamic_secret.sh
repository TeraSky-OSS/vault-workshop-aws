#!/bin/bash

########################
# include the magic
########################
. demo-magic.sh

# hide the evidence
clear

p "Vault AWS Dynamic secrets Demo."
TYPE_SPEED=80
p "Enable the AWS secrets engine:"
pe "vault secrets enable aws"

p "Configure the credentials that Vault uses to communicate with AWS to generate the IAM credentials"
p "vault write aws/config/root \
    access_key=AKIBLABLABLABLABLA \
    secret_key=654gds65fg6d5f4g65dsf4g65s4df6g54s6dfg4 \
    region=$CURRENT_AWS_REGION"
vault write aws/config/root \
    access_key=$(grep -o 'aws_access[^"]*' /home/ubuntu/.aws/credentials | cut -c 19-) \
    secret_key=$(grep -o 'aws_secret[^"]*' /home/ubuntu/.aws/credentials | cut -c 23-) \
    region=$CURRENT_AWS_REGION

p "it also a good practice to rotate the initial root credentials,so it will only be accessible to vault"
p "vault write -f aws/config/rotate-root"

p "Configure a Vault role that maps to a set of permissions in AWS as well as an AWS credential type. \nWhen users generate credentials, they are generated against this role."
p "vault write aws/roles/my-role \
    credential_type=iam_user \
    policy_document=-<<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ec2:*",
      "Resource": "*"
    }
  ]
}
EOF"
vault write aws/roles/my-role \
    credential_type=iam_user \
    policy_document=-<<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ec2:*",
      "Resource": "*"
    }
  ]
}
EOF
p "This creates a role named "my-role". When users generate credentials against this role, Vault will create an IAM user and attach the specified policy document to the IAM user. Vault will then create an access key and secret key for the IAM user and return these credentials. You supply a user inline policy and/or provide references to an existing AWS policy's full ARN and/or a list of IAM groups:"
p "vault write aws/roles/my-other-role \
    policy_arns=arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess,arn:aws:iam::aws:policy/IAMReadOnlyAccess \
    iam_groups=group1,group2 \
    credential_type=iam_user \
    policy_document=-<<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ec2:*",
      "Resource": "*"
    }
  ]
}
EOF"
vault write aws/roles/my-other-role \
    policy_arns=arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess,arn:aws:iam::aws:policy/IAMReadOnlyAccess \
    iam_groups=group1,group2 \
    credential_type=iam_user \
    policy_document=-<<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ec2:*",
      "Resource": "*"
    }
  ]
}
EOF

p "After the secrets engine is configured and a user/machine has a Vault token with the proper permission, it can generate credentials."
p "vault read aws/creds/my-role"
vault read aws/creds/my-role > aws_role.txt
cat aws_role.txt

p "The above demonstrated usage with iam_user credential types. Vault also supports assumed_role and federation_token credential types."

p "now, lets manualy revoke the aws dynamic credentials"
pe "vault lease revoke $(grep -o 'lease_id[^"]*' zz.txt | cut -c 20-)"

p "full info and features of vault AWS Dynamic secrets can be found on the official vault documentations at:"
p "https://developer.hashicorp.com/vault/docs/secrets/aws"

p "Demo End."

vault secrets disable aws