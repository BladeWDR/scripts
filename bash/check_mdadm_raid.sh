#!/usr/bin/env bash

MDSTAT='/proc/mdstat'

if [ ! -f "$MDSTAT" ]; then
    exit 3 "/proc/mdstat does not exist!"
fi

# create a test array here to see what it would look like if i had multiple.
devices=$(ls /dev | grep -e ^md[0-9]$)
check=0
declare -a devicestatus

for device in $devices; do
    status=$(mdadm --detail "/dev/$device" | grep -e '^\s*State : ' | awk '{ print $NF; }')

    if [[ status != "clean" ]] || [[ status != "active" ]]; then
        devicestatus+=("$status")
    fi
done

# would like to add some logic to report WHICH volume is having problems, in the case where there may be multiple.
if [[ ! -z "${devicestatus[@]}" ]]; then
    echo "All mdadm volumes not clean! \n $devicestatus"
    exit 3
else
    echo "All mdadm volumes clean."
    exit 0
fi
