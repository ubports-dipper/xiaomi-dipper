#!/sbin/sh

DATA_MOUNT_CODE=1

while [ "$DATA_MOUNT_CODE" != "0" ]; do
    mount -t ext4 /dev/block/bootdevice/by-name/userdata /data > /dev/kmsg
    DATA_MOUNT_CODE=$?
    sleep 1
done

mkdir /data/cache > /dev/kmsg
mount -o bind /data/cache /cache > /dev/kmsgs

setprop halium.datamount.done 1

exit 0
