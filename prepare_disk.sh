#!/bin/bash

# This script assumes the standard naming conventions are used
# google-prod-data-east1-pbx1
# prod-east1-pbx1-d
TYPE=`hostname | cut -d "-" -f 1`
REGION=`hostname | cut -d "-" -f 2`
INSTANCE=`hostname | cut -d "-" -f 3`
DISK=/dev/disk/by-id/google-${TYPE}-data-${REGION}-${INSTANCE}

MOUNT_OPTIONS="discard,defaults"
MOUNTPOINT=/data
MKFS="mkfs.ext4 -E lazy_itable_init=0,lazy_journal_init=0 -F"

if [ "$EUID" -ne 0 ]
        then echo "Please run as root"
        exit
fi

function disk_looks_unformatted() {
        local readonly file_type=$(file --special-files --dereference ${DISK})
        case ${file_type} in
                *filesystem*)
                return 0
        esac

        return 1
}

disk_looks_unformatted ${DISK}

if [[ $? != 0 ]]; then
        echo "Disk does not appear to be formatted, formatting ..."
        ${MKFS} ${DISK}
fi

UUID=`blkid -s UUID -o value ${DISK}`

if [ ! -z `grep ${UUID} /etc/fstab | cut -d " " -f 1` ]; then
        echo "Disk already added to /etc/fstab, exiting."
        exit 0
fi

echo "Adding disk ${UUID} to /etc/fstab ..."
echo "UUID=${UUID} ${MOUNTPOINT} ext4 discard,defaults,nofail 0 2" >> /etc/fstab
mkdir -p ${MOUNTPOINT}
mount ${MOUNTPOINT}
