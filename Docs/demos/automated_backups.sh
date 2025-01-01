#!/bin/bash

########################
# include the magic
########################
. demo-magic.sh

# hide the evidence
clear

p "Vault Automated Backups Demo."

p "Enable Automated Snapshots with the following command:"
p "vault write sys/storage/raft/snapshot-auto/config/[:name] [options]"
p "for example, The following command creates a automatic snapshot configuration named, testsnap with a user defined location and interval. It retains up to 7 snapshots before deleting any old snapshot."
p "vault write sys/storage/raft/snapshot-auto/config/testsnap 
     storage_type=local 
     file_prefix=testsnappy 
     interval=120m 
     retain=7 
     local_max_space=1000000 
     path_prefix=/opt/vault/"
vault write sys/storage/raft/snapshot-auto/config/testsnap \
     storage_type=local \
     file_prefix=testsnappy \
     interval=120m \
     retain=7 \
     local_max_space=1000000 \
     path_prefix=/opt/vault/

pe "ls /opt/vault/"

p "full info and features of vault Automated Backups can be found on the official vault documentations at:"
p "https://developer.hashicorp.com/vault/tutorials/standard-procedures/sop-backup"

p "Demo End."