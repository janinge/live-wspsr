#!/bin/bash

ACTION=$1
DEVBASE=$2
DEVICE="/dev/${DEVBASE}"

# See if this drive is already mounted
MOUNT_POINT=$(grep ${DEVICE} /proc/mounts | awk '{ print $2 }')

do_mount()
{
    if [[ -n ${MOUNT_POINT} ]]; then
        # Already mounted, exit
        exit 1
    fi

    LIVE=$(grep /run/live/medium /proc/mounts | awk '{ split($1,a,/[0-9]+/); print a[1];}')
    if [[ $DEVICE = $LIVE* ]]; then
        # Different partition on live medium, exit
        exit 1
    fi

    # Get info for this drive: DEVNAME, LABEL, UUID, BLOCK_SIZE, TYPE, PARTLABEL, PARTUUID
    eval $(/sbin/blkid -o export ${DEVICE})

    # Figure out a mount point to use
    if [[ -z "${LABEL}" ]]; then
        LABEL=${PARTUUID}
    elif [[ -z "${LABEL}" ]]; then
        LABEL=${DEVBASE}
    elif /bin/grep -q " /media/${LABEL} " /etc/mtab; then
        # Already in use, make a unique one
        LABEL+="-${DEVBASE}"
    fi
    MOUNT_POINT="/media/${LABEL}"

    /bin/mkdir -p ${MOUNT_POINT}

    # Global mount options
    OPTS="rw,sync,uid=1000,gid=1000,dmask=007,fmask=117,users"

    # File system type specific mount options
    if [[ ${TYPE} == "vfat" ]]; then
        OPTS+=",utf8=1,flush"
    fi

    if ! /bin/mount -o ${OPTS} ${DEVICE} ${MOUNT_POINT}; then
        # Error during mount process: cleanup mountpoint
        /bin/rmdir ${MOUNT_POINT}
        exit 1
    fi
}

do_unmount()
{
    if [[ -n ${MOUNT_POINT} ]]; then
        /bin/umount -l ${DEVICE} || :
	find /media -maxdepth 1 -mindepth 1 -mount -empty -type d -delete
    fi
}

case "${ACTION}" in
    add)
        do_mount
        ;;
    remove)
        do_unmount
        ;;
esac
