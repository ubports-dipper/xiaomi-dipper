#!/bin/sh
# Based on https://raw.githubusercontent.com/ubports/Jumpdrive/ubports-recovery/initramfs/system-image-upgrader
# Modified and simplified to create flashable system.img from OTA files
set -e

HERE=$(pwd)
SRC="$(realpath $(dirname "$1" 2>/dev/null || echo 'src'))"
OUT="$(realpath "$2" 2>/dev/null || echo 'out')"

logit() {
    echo "System image: $1"
    echo "System image: $1" >> /tmp/system-image/system-image-upgrader.log
}

mkdir -p /tmp/system-image
echo "-- System image log --" > /tmp/system-image/system-image-upgrader.log
logit "Starting image Upgrade pre"
if [ ! -e "$1" ]; then
    logit "Command file doesn't exist: $1"
    exit 1
fi

COMMAND_FILE=$(realpath "$1")

REMOVE_LIST="$COMMAND_FILE"

# Used as a security check to see if we would change the password
DATA_FORMAT=0

TMP=$(mktemp -d -p /tmp/system-image)
mkdir -p "$OUT"

# System Mountpoint
SYSTEM_MOUNTPOINT="$TMP/system"
mkdir -p "$SYSTEM_MOUNTPOINT"

logit "Starting image upgrader: $(date)"

TOTAL=$(cat $COMMAND_FILE | wc -l)

progress() {
    # Devide by 0 will make go boom!
    if [ "$1" == "0" ]; then
        # echo "0" > cmd_pipe
        @
    fi
    PRE=$(awk -vn="$1" -vt="$TOTAL" 'BEGIN{printf("%.0f\n",n/t*100)}')
    # echo "$PRE" > cmd_pipe
}

# Functions
check_filesystem() {
    return 0
}

verify_signature() {
    return 0
}

install_keyring() {
    # $1 => full path to tarball
    # $2 => full path to signature

    # Some basic checks
    if [ ! -e "$1" ] || [ ! -e "$2" ]; then
        logit "Missing keyring files: $1 => $2"
        return 1
    fi

    # Unpacking
    TMPDIR=$(mktemp -dt -p /tmp/system-image/ tmp.XXXXXXXXXX)
    cd $TMPDIR
    xzcat $1 | tar --numeric-owner -xf -
    if [ ! -e keyring.json ] || [ ! -e keyring.gpg ]; then
        rm -Rf $TMPDIR
        logit "Invalid keyring: $1"
        return 1
    fi

    # Extract the expiry
    keyring_expiry=$(grep "^    \"expiry\": " keyring.json | cut -d: -f2 | sed -e "s/[ \",]//g")
    if [ -n "$keyring_expiry" ] && [ "$keyring_expiry" -lt "$(date +%s)" ]; then
        rm -Rf $TMPDIR
        logit "Keyring expired: $1"
        return 1
    fi

    # Extract the keyring type
    keyring_type=$(grep "^    \"type\": " keyring.json | cut -d: -f2 | sed -e "s/[, \"]//g")
    if [ -z "$keyring_type" ]; then
        rm -Rf $TMPDIR
        logit "Missing keyring type: $1"
        return 1
    fi

    if [ -e /tmp/system-image/$keyring_type ]; then
        rm -Rf $TMPDIR
        logit "Keyring already loaded: $1"
        return 1
    fi

    signer="unknown"
    case "$keyring_type" in
        archive-master)
            signer=""
        ;;

        image-master)
            signer="archive-master"
        ;;

        image-signing|blacklist)
            signer="image-master"
        ;;

        device-signing)
            signer="image-signing"
        ;;
    esac

    if [ -n "$signer" ] && ! verify_signature $signer $2; then
        rm -Rf $TMPDIR
        logit "Invalid signature: $1"
        return 1
    fi

    mkdir /tmp/system-image/$keyring_type
    # chmod 700 /tmp/system-image/$keyring_type
    mv $TMPDIR/keyring.gpg /tmp/system-image/$keyring_type/pubring.gpg
    # chmod 600 /tmp/system-image/$keyring_type/pubring.gpg
    # chown 0:0 /tmp/system-image/$keyring_type/pubring.gpg
    rm -Rf $TMPDIR
    return 0
}

factory_wipe() {
    # only set this flag if coming from a data wipe
    if [ "$DATA_FORMAT" -eq 0 ]; then
        return 1
    fi

    flag="/data/.factory_wipe"
    # if the param != "true" we just delete the flag
    case $1 in
        true)
            touch "$flag"
        ;;

        false)
            rm -f "$flag"
        ;;

        *)
            logit "Unkown parameter $1, disabling"
            rm -f "$flag"
        ;;
    esac
}

# Initialize GPG
rm -Rf /tmp/system-image
mkdir -p /tmp/system-image
if [ -e /etc/system-image/archive-master.tar.xz ]; then
    logit "Loading keyring: archive-master.tar.xz"
    install_keyring /etc/system-image/archive-master.tar.xz /etc/system-image/archive-master.tar.xz.asc
fi

# Process the command file
FULL_IMAGE=0
logit "Processing the command file"

count=0
while read line
do
    set -- $line
    case "$1" in
        format)
            logit "Formating: $2"
            case "$2" in
                system)
                    FULL_IMAGE=1
                    rm -f "$OUT/rootfs.img"
                    dd if=/dev/zero of="$OUT/rootfs.img" seek=750K bs=4096 count=0
                    mkfs.ext4 -F "$OUT/rootfs.img"
                ;;

                *)
                    logit "Unknown format target: $2"
                ;;
            esac
        ;;

        load_keyring)
            if [ ! -e "$SRC/$2" ] || [ ! -e "$SRC/$3" ]; then
                logit "Skipping missing file: $SRC/$2"
                continue
            fi
            REMOVE_LIST="$REMOVE_LIST $SRC/$2 $SRC/$3"

            logit "Loading keyring: $2"
            install_keyring $SRC/$2 $SRC/$3
        ;;

        mount)
            case "$2" in
                system)
                    mkdir -p "$SYSTEM_MOUNTPOINT"
                    LOOPDEV=$(losetup -f)

                    if [ ! -e "$LOOPDEV" ]; then
                        sudo mknod "$LOOPDEV" b 7 $(echo "$LOOPDEV" | grep -Eo '[0-9]+$')
                        sudo losetup "$LOOPDEV" "$OUT/rootfs.img"
                        sudo mount "$LOOPDEV" "$SYSTEM_MOUNTPOINT/"
                    else
                        sudo mount -o loop "$OUT/rootfs.img" "$SYSTEM_MOUNTPOINT/"
                    fi
                ;;

                *)
                    logit "Unknown mount target: $2"
                ;;
            esac
        ;;

        unmount)
            case "$2" in
                system)
                    sudo umount "$SYSTEM_MOUNTPOINT"
                    rmdir "$SYSTEM_MOUNTPOINT"
                    # Create fastboot flashable image
                    img2simg "$OUT/rootfs.img" "$OUT/system.img"
                ;;

                *)
                    logit "Unknown mount target: $2"
                ;;
            esac
        ;;

        update)
            if [ ! -e "$SRC/$2" ] || [ ! -e "$SRC/$3" ]; then
                logit "Skipping missing file: $2"
                continue
            fi

            REMOVE_LIST="$REMOVE_LIST $SRC/$3"

            if ! verify_signature device-signing $SRC/$3 && \
               ! verify_signature image-signing $SRC/$3; then
                logit "Invalid signature"
                exit 1
            fi

            logit "Applying update: $2"
            cd "$TMP"
            rm -Rf partitions

            # Start by removing any file listed in "removed"
            if [ "$FULL_IMAGE" != "1" ]; then
                xzcat "$SRC/$2" | tar --numeric-owner -xf - removed >/dev/null 2>&1 || true
                if [ -e removed ]; then
                    while read file; do
                        rm -Rf $file
                    done < removed
                fi
                rm -f removed
            fi

            # Unpack everything else on top of the system partition
            sudo sh -c "xzcat \"$SRC/$2\" | tar --numeric-owner -xf -"
            rm -f removed

            # Move things to data
            cp partitions/* "$OUT" || true
            sudo rm -Rf partitions || true

            # Remove tarball to free up space, since device tarballs
            # extract partitions/blobs that might fill up cache,
            # this way we ensure we got space for the partitions/blobs
            # rm -f recovery/$2
        ;;

        *)
            logit "Unknown command: $1"
        ;;
    esac

    count=$((count+=1))
    progress $count
done < $COMMAND_FILE

if [ -e "$LOOPDEV" ]; then
    sudo losetup -d "$LOOPDEV" || true
fi

# Remove the update files
#for file in $REMOVE_LIST; do
#    rm -f $file
#done
logit "Can be removed: $REMOVE_LIST"

sync

logit "Done upgrading: $(date)"
