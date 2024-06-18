#!/bin/bash

# Variables

DATE=$(date +%Y-%m-%d-%H-%M-%S)
BACKUP_DIR=/tmp/mongodbbackup
DATABASE_NAME=admin
GCS_BUCKET=gs://backups-mrj

# Perform MongoDB backup using mongodump

mongodump --db $DATABASE_NAME --out $BACKUP_DIR/$DATE

# Check if the backup directory is empty before proceeding
if [ -z "$(ls -A $BACKUP_DIR/$DATE)" ]; then
    echo "Backup directory is empty. Exiting."
    exit 1
fi

# Compress the backup using tar
tar -czf $BACKUP_DIR/$DATE.tar.gz -C $BACKUP_DIR $DATE

# Upload backup to Google Cloud Storage
gsutil -m cp -r $BACKUP_DIR/$DATE.tar.gz $GCS_BUCKET/mongodb-backups/$DATE.tar.gz

#Clean up local backup files
rm -rf $BACKUP_DIR/$DATE
rm $BACKUP_DIR/$DATE.tar.gz