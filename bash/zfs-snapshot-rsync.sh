#!/usr/bin/env bash
# Don't use this, use a ZFS replication tool like Sanoid. This is just me workshopping how I would write a script to rsync directly from a snapshot.
# If you do insist, call it with zfs-snapshot-rsync.sh dataset destination

set -euo pipefail

dataset="$1"

# Get the latest snapshot.
snap=$(zfs list -t snap -o name -S name -H $dataset | head -n 1)

# Trim the dataset from the snapshot name.
snap=$(echo "$snap" | sed "s/${dataset//\//\\/}@//g")

# Get the dataset mountpoint.
read -r snapdir <<< "$(zfs get -H -o value mountpoint "$dataset")"

snapdir+="/.zfs/snapshot"

# construct source directory path.
sourcedir="$snapdir/$snap/"
destdir="$2"

rsync -avh --info=progress2 --update $sourcedir $destdir
