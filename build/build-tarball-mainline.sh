set -ex

device=$1
output=$(realpath $2)
dir=$(realpath $3)

echo "Working on device: $device"
if [ ! -f "$dir/partitions/boot.img" ]; then
    echo "boot.img does not exist!"
exit 1; fi

if [ ! -f "$dir/partitions/recovery.img" ]; then
    echo "recovery.img does not exist!"
#exit 1
fi

tar -cJf "$output/device_"$device".tar.xz" -C $dir partitions/ system/
echo "$(date +%Y%m%d)-$RANDOM" > "$output/device_"$device".tar.build"
