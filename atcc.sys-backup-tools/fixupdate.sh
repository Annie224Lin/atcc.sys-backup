#!/bin/sh

if [ $# -lt 1 ]; then
    exit 0;
fi

case "$1" in
"preinst")
	# do format rootfs if not has journal for previous version
	HAS_JOURNAL=$(dumpe2fs /dev/mmcblk2p3 2>&1 | grep has_journal)
	if [ -z "$HAS_JOURNAL" ]; then
		mkfs.ext4 -F -q -L "rootfs" /dev/mmcblk2p3
	fi
	;;
"postinst")
	fsck.vfat -f -y /dev/mmcblk2p1 2>&1
	## resize2fs mmcblk2p3
	fsck.ext4 -f -y /dev/mmcblk2p3 2>&1
	resize2fs -F /dev/mmcblk2p3  2>&1
	;;
esac

exit 0;
