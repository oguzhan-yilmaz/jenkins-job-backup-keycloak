#!/usr/bin/env bash

# SRC: https://gist.github.com/michaelknurr/a8f1941c6f40c0d784b1e467fbc694ba
# export command fails issue fix: https://github.com/bitnami/charts/issues/13105
echo "--------------------- START of keycloak-auto-export-script.sh -------------------------"

export KEYCLOAK_HOME="/opt/bitnami/keycloak"
export KEYCLOAK_BACKUP_DIR="/tmp/keycloak-auto-backups"
export KEYCLOAK_BACKUP_ZIP_PATH="/tmp/keycloak-auto-backups.tar"

echo "KEYCLOAK_HOME=$KEYCLOAK_HOME"
echo "KEYCLOAK_BACKUP_DIR=$KEYCLOAK_BACKUP_DIR"
echo "KEYCLOAK_BACKUP_ZIP_PATH=$KEYCLOAK_BACKUP_ZIP_PATH"

# # check, if another export is currently running
# if [ $(ps -ef | grep "keycloak.migration.action=export" | grep -v grep | wc -l) != 0 ]; then
#     echo "Another export is currently running. Exiting this one.";
#     exit 1;
# fi


if [ ! -d "$KEYCLOAK_HOME" ]; then
    echo "Directory KEYCLOAK_HOME=$KEYCLOAK_HOME does not exist. Exiting";
    exit 1;
fi


# delete the backup directory and zip if it exists
if [ -d "$KEYCLOAK_BACKUP_DIR" ]; then
    echo "KEYCLOAK_BACKUP_DIR exists. Deleting $KEYCLOAK_BACKUP_DIR"
    rm -rf $KEYCLOAK_BACKUP_DIR
fi

if [ -f "$KEYCLOAK_BACKUP_ZIP_PATH" ]; then
    echo "KEYCLOAK_BACKUP_ZIP_PATH exists. Deleting existing backup zip file: $KEYCLOAK_BACKUP_ZIP_PATH"
    rm "$KEYCLOAK_BACKUP_ZIP_PATH"
fi


echo "Running keycloak export command..."
$KEYCLOAK_HOME/bin/kc.sh export \
    --users=different_files \
    --dir=$KEYCLOAK_BACKUP_DIR \
    --users-per-file=500 

echo "Keycloak Export finished"
echo "Listing backup dir: $KEYCLOAK_BACKUP_DIR"
ls -alh $KEYCLOAK_BACKUP_DIR

# zip the backup directory
echo "Zipping backup directory..."
cd $KEYCLOAK_BACKUP_DIR || { echo "Can't cd into $KEYCLOAK_BACKUP_DIR. Exiting."; exit 1; };
pwd
tar -czvf $KEYCLOAK_BACKUP_ZIP_PATH . || { echo "Can't tar archive $KEYCLOAK_BACKUP_DIR. Exiting."; exit 1; };

echo "Checking if tar file exists at $KEYCLOAK_BACKUP_ZIP_PATH"
ls -alh $KEYCLOAK_BACKUP_ZIP_PATH

echo "Backup directory zipped to $KEYCLOAK_BACKUP_ZIP_PATH"
echo "Backup completed successfully. Exiting."
echo "--------------------- END of keycloak-auto-export-script.sh -------------------------"
exit 0