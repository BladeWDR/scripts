#!/bin/bash

current_date=$(date +%Y%m%d)
backup_dir=/mnt/syncthing/Documents/immich-backup

check_oldest () {

reference_time=$(date -d "3 days ago" +%s)

# Iterate through all files in the directory
for file in "$backup_dir"/*; do
    if [ -f "$file" ]; then
        # Check the file creation time using stat
        creation_time=$(stat -c %W "$file")

        # Calculate the time difference
        time_difference=$((reference_time - creation_time))

        # Check if the file is more than 3 days old
        if [ "$time_difference" -gt 0 ]; then
            # Delete the file
            rm "$file"
        fi
    fi
done

}

# Create today's dump file.
docker exec -t immich_database pg_dumpall -c -U postgres | gzip > "/mnt/syncthing/Documents/immich_backup/${current_date}-immich-dump.sql.gz"

# Prune any files older than 3 days.
check_oldest
