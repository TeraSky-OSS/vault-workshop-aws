#!/bin/bash

########################
# include the magic
########################
. demo-magic.sh

# hide the evidence
clear

p "Vault Snapshot Demo."



p "lets take a vault snapshot:"
pe "vault operator raft snapshot save primary.snap"
p "and another one..."
pe "vault operator raft snapshot save secondary.snap"
pe "ls -al *.snap"

p "Now, lets restore a snapshot:"
pe "vault operator raft snapshot restore primary.snap"

p "full info and features of vault snapshots can be found on the official vault documentations at:"
p "https://developer.hashicorp.com/vault/docs/enterprise/automated-integrated-storage-snapshots"


p "Demo End."

rm primary.snap
rm secondary.snap