#!/bin/bash

###########################################################
# Automated Backup Script
# This script performs MySQL database and file system backups
# and synchronizes them to a remote server using rsync.
#
# Usage:
# 1. Customize the directories, usernames, and other details.
# 2. Make the script executable: chmod +x backup_script.sh
# 3. Run the script: ./backup_script.sh
#
# Note: Ensure that necessary permissions and configurations
# are set for MySQL backup and rsync to work correctly.
###########################################################
# MySQL database connection details
mysql_backup_dir="/path/to/backupdir/"
source_directories=("/var/www" "/etc/nginx/sites-available" "/etc/apache2/sites-available")
backup_parent_dir="/path/to/backupdir/"
log_file="$backup_parent_dir/backup_log.txt"

# Function to log messages
log_message() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") $1" >> "$log_file"
}

# MySQL Backup
timestamp=$(date +"%Y%m%d_%H%M%S")
databases=$(mysql -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema|mysql)")

for database in $databases; do
    backup_filename="${database}_backup_$timestamp.sql"
    backup_file="$mysql_backup_dir/$backup_filename"

    mysqldump --databases "$database" > "$backup_file"

    if [ $? -eq 0 ]; then
        log_message "MySQL Backup successful for database: $database. File: $backup_file"
        ls -t "$mysql_backup_dir/${database}_backup_"*.sql | tail -n +4 | xargs rm -f
    else
        log_message "MySQL Backup failed for database: $database."
    fi
done

# File System Backup
for source_dir in "${source_directories[@]}"; do
    if [ -d "$source_dir" ]; then
        base_dir_name=$(basename "$source_dir")
        backup_filename="${base_dir_name}_backup_$timestamp.tar.gz"
        backup_file="$backup_parent_dir/$backup_filename"

        tar -czvf "$backup_file" -C "$(dirname "$source_dir")" "$base_dir_name" >> "$log_file" 2>&1

        if [ $? -eq 0 ]; then
            log_message "File System Backup successful for $base_dir_name. File: $backup_file"
        else
            log_message "File System Backup failed for $base_dir_name."
            continue
        fi

        ls -t "$backup_parent_dir/${base_dir_name}_backup_"*.tar.gz | tail -n +4 | xargs rm -f
    else
        log_message "Source directory $source_dir does not exist. Skipping."
    fi
done

# Rsync
rsync -a --delete "$backup_parent_dir" digitaluser@161.35.137.255:"/mnt/volume_nyc3_01/backup-importnt/" >> "$log_file" 2>&1

if [ $? -eq 0 ]; then
    log_message "Rsync successful."
else
    log_message "Rsync failed."
fi
