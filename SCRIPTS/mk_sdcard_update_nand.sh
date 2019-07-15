#!/bin/sh

FAT_SIZE=500M

uboot=u-boot-imx6ull14x14evk.imx-sd
dtb=imx6ull-14x14-evk.dtb
boot=zImage
rootfs=rootfs.tar.bz2

if [ $# -gt 0 ]; then
   
	if [ $# -gt 1 ]; then		
		echo "Incorrect number of parameters"
		echo "if the sdcard mounted,need umount this sdcard."
       	echo "sudo ./mk_sdcard_update_nand.sh /dev/sd[a-z] or sudo bash mk_sdcard_update_nand.sh /dev/sd[a-z]"
		exit 1
	fi
		
else
        echo "Usage:"
        echo "if the sdcard mounted,need umount this sdcard."
       	echo "sudo ./mk_sdcard_update_nand.sh /dev/sd[a-z] or sudo bash mk_sdcard_update_nand.sh /dev/sd[a-z]"
		exit 2
fi

mksdcard() {
# partition size in MB
BOOT_ROM_SIZE=10

# wait for the SD device node ready
while [ ! -e $1 ]
do
sleep 1
echo “wait for $1 appear”
done

# call sfdisk to create partition table
# destroy the partition table
node=$1
dd if=/dev/zero of=${node} bs=1024 count=1

sfdisk --force ${node} << EOF
${BOOT_ROM_SIZE}M,$FAT_SIZE,0c
$FAT_SIZE,,83
EOF
}

check_exit() {
    result=$?
    if [ $result != 0 ]; then        
        echo "#### $1 $2 $3 fail: $result ####"
		
	exit $result
    fi
}

if [ -b $1 ]; then

if [ ! -e ${uboot} ];then
echo "not found:${uboot}"
exit 1;
fi

if [ ! -e ${dtb} ];then
echo "not found:${dtb}"
exit 1;
fi


if [ ! -e ${boot} ];then
echo "not found:${boot}"
exit 1;
fi

if [ ! -e ${rootfs} ];then
echo "not found:${rootfs}"
exit 1;
fi

echo ""
echo "Attention:"
echo "The storage contents will be deleted permanently!!!"
read -t 20 -p "Are you sure you want to continue:$1?(y/n)" yes
echo $yes

if [ "$yes" = "y" ]; then
	
rm fat -Rf
rm linux -Rf

mksdcard $1

check_exit sfdisk $1

fat_node=${1}1
linux_node=${1}2

echo fat path:$fat_node
echo linux path:$linux_node

dd if=/dev/zero of=$1 bs=1k seek=768 conv=fsync count=8
dd if=${uboot} of=$1 bs=1k seek=1 conv=fsync

check_exit write uboot

mkfs.vfat $fat_node

check_exit mkfs.vfat $fat_node

mkdir -p fat 

mount -t vfat $fat_node fat

check_exit mount $fat_node

cp ${boot} fat

check_exit cp ${boot}

cp ${dtb} fat

check_exit cp ${dtb}

umount fat

check_exit umount fat

rm fat -Rf

mkfs.ext3 -F -j $linux_node

check_exit mkfs.ext3 $linux_node

mkdir -p linux  

mount -t ext3 $linux_node linux

check_exit mount $linux_node

tar -jxvf ${rootfs} -C linux

check_exit ${rootfs}

umount linux

check_exit umount linux

rm linux -Rf

echo Done...
fi
else
echo Not found device node:$1
exit 3
fi
