#!/bin/bash
# it is used to build rootfs.ext4 for swupdate-tools

ROOT=$(pwd)

ABS_ROOTFS=/dev/mmcblk2
ABS_DIR_ROOTFS=$1
ABS_EXT4_OUT_FILE=${ROOT}/rootfs.ext4
ABS_EXT4_OUT_DIR="$(mktemp)"
DATE=$(date '+%Y-%m-%d %H:%M:%S')
LOG_FILE=/run/media/sda1/atcc.sys-backup.log


remove_files(){

        echo "clone system" > ${ABS_EXT4_OUT_DIR}/etc/.adv_reinit
        #network config
        rm -rf ${ABS_EXT4_OUT_DIR}/var/lib/connman/*

        #ssh host ,ssh private keys
        [ -f ${ABS_EXT4_OUT_DIR}/home/root/.ssh ] && rm -rf ${ABS_EXT4_OUT_DIR}/home/root/.ssh
        [ -f ${ABS_EXT4_OUT_DIR}/etc/ssh/ssh_host_ed25519_key ] && rm -rf ${ABS_EXT4_OUT_DIR}/etc/ssh/ssh_host_ed25519_key
        [ -f ${ABS_EXT4_OUT_DIR}/etc/ssh/ssh_host_dsa_key ] && rm -rf ${ABS_EXT4_OUT_DIR}/etc/ssh/ssh_host_dsa_key
        [ -f ${ABS_EXT4_OUT_DIR}/etc/ssh/ssh_host_ecdsa_key ] && rm -rf ${ABS_EXT4_OUT_DIR}/etc/ssh/ssh_host_ecdsa_key
        [ -f ${ABS_EXT4_OUT_DIR}/etc/ssh/ssh_host_rsa_key ] && rm -rf ${ABS_EXT4_OUT_DIR}/etc/ssh/ssh_host_rsa_key

        #log message
        rm -rf ${ABS_EXT4_OUT_DIR}/var/log/*

        #machine id
        rm -rf ${ABS_EXT4_OUT_DIR}/etc/machine-id

        #opcua  certificates
        rm -rf ${ABS_EXT4_OUT_DIR}/opt/adv-opcua/*.der

        #private key and certitficate 
        [ -f ${ABS_EXT4_OUT_DIR}/usr/src/device/backup_image/aes_key.sig ] && rm -rf ${ABS_EXT4_OUT_DIR}/usr/src/device/backup_image/aes_key.sig
        [ -f ${ABS_EXT4_OUT_DIR}/etc/ssl/private/backup_priv.pem ] && rm -rf ${ABS_EXT4_OUT_DIR}/etc/ssl/private/backup_priv.pem

        target_cert="/usr/local/share/ca-certificates/backup_ca.crt"
        find "/etc/ssl/certs" -type l -exec bash -c '
            for symlink; do
            if [ "$(readlink -f "${symlink}")" = "$0" ]; then
                rm "${ABS_EXT4_OUT_DIR}/${symlink}"                
            fi
            done
        ' "${target_cert}" {} +
        
        [ -f ${ABS_EXT4_OUT_DIR}/${target_cert} ] && rm -rf ${ABS_EXT4_OUT_DIR}/${target_cert}
}



if [ ! -e $ABS_DIR_ROOTFS ]; then
	echo "there is no file system here" >> ${LOG_FILE}
	echo "exit backup operate"
	exit 1
fi


[[  -e "$ABS_EXT4_OUT_DIR" ]] && rm -rf "$ABS_EXT4_OUT_DIR"
mkdir -p $ABS_EXT4_OUT_DIR 

[[ -e "$ABS_EXT4_OUT_FILE" ]] && rm -f $ABS_EXT4_OUT_FILE  && echo "delete old rootfs.ext4"
df -hm
ROOTFS_SIZE=`df -hm  | grep $ABS_DIR_ROOTFS | awk -F ' ' '{print $3}'|   tr -d 'M|G|T'`
ROOTFS_SIZE_WITH_1M=$(( ${ROOTFS_SIZE}+200 ))
dd if=/dev/zero of=$ABS_EXT4_OUT_FILE bs=1M count=${ROOTFS_SIZE_WITH_1M}
sync
sync
mkfs.ext4 $ABS_EXT4_OUT_FILE  1>/dev/null 2>&1 
RETURN_CODE=$?
if [ $RETURN_CODE -ne 0 ]; then
   echo "Error! mkfs.ext4 $ABS_EXT4_OUT_FILE failed"  >> $LOG_FILE
   exit 1
fi

mount -o loop $ABS_EXT4_OUT_FILE $ABS_EXT4_OUT_DIR 
RETURN_CODE=$?
if [ $RETURN_CODE -ne 0 ]; then
   echo "Error! mount $ABS_EXT4_OUT_FILE failed"  >> $LOG_FILE
   exit 1
fi

if [ ! -e $ABS_DIR_ROOTFS ] ;then 
    echo "lost usb device "  >> $LOG_FILE
    echo "no rootfs here or no USB device"
    exit 1
else
    echo "[start copy system file $(date '+%Y-%m-%d %H:%M:%S')]"  >> $LOG_FILE
fi

cp -rf --preserve=all $ABS_DIR_ROOTFS/* $ABS_EXT4_OUT_DIR
RETURN_CODE=$?
if [ $RETURN_CODE -ne 0 ]; then
   echo "Error! copy system file failed"  >> $LOG_FILE
   exit 1
fi
sync
sync
remove_files
echo "BACKUPTIME="$DATE"" >>$ABS_EXT4_OUT_DIR/etc/os-release

umount -d $ABS_EXT4_OUT_DIR 
rm -rf $ABS_EXT4_OUT_DIR

exit 0 




