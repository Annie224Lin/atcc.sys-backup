#!/bin/sh

export PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin"

EMMC_DEVICE_NODE="/dev/mmcblk2"
ABS_DIR_SYSTEM="/run/media/mmcblk2p3"
USB_SOURCE=$1
ABS_EXT4_OUT_FILE=${USB_SOURCE}/rootfs.ext4
ABS_ZSTD_OUT_FILE=${USB_SOURCE}/rootfs.zstd
ABS_BACKUP_SYSTEM="$(mktemp)"
ABS_BACKUP_NAME="atcc.sys-backup"
ABS_RESTORE_SYSTEM="$(mktemp)"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

if [ $# -ne 0 ]; then
   USB_SOURCE=$1
fi

function psplash_progress
{
        /usr/bin/psplash-write "PROGRESS $1"
        return 0
}

function psplash_message
{
        /usr/bin/psplash-write "MSG $1"
        return 0
}

function psplash_quit
{
        umount $MOUNT_ISO_PATH
        sleep 5
        /usr/bin/psplash-write "QUIT"
        exit 0
}

remove_files(){

        echo "clone system" > ${ABS_BACKUP_SYSTEM}/etc/.adv_reinit
        #network config
        rm -rf ${ABS_BACKUP_SYSTEM}/var/lib/connman/*

        #ssh host ,ssh private keys
        [ -f ${ABS_BACKUP_SYSTEM}/home/root/.ssh ] && rm -rf ${ABS_BACKUP_SYSTEM}/home/root/.ssh
        [ -f ${ABS_BACKUP_SYSTEM}/etc/ssh/ssh_host_ed25519_key ] && rm ${ABS_BACKUP_SYSTEM}/etc/ssh/ssh_host_ed25519_key
        [ -f ${ABS_BACKUP_SYSTEM}/etc/ssh/ssh_host_dsa_key ] && rm ${ABS_BACKUP_SYSTEM}/etc/ssh/ssh_host_dsa_key
        [ -f ${ABS_BACKUP_SYSTEM}/etc/ssh/ssh_host_ecdsa_key ] && rm ${ABS_BACKUP_SYSTEM}/etc/ssh/ssh_host_ecdsa_key
        [ -f ${ABS_BACKUP_SYSTEM}/etc/ssh/ssh_host_rsa_key ] && rm ${ABS_BACKUP_SYSTEM}/etc/ssh/ssh_host_rsa_key

        #log message
        rm -rf ${ABS_BACKUP_SYSTEM}/var/log/*

        #machine id
        rm -rf ${ABS_BACKUP_SYSTEM}/etc/machine-id

        #opcua  certificates
        rm -rf ${ABS_BACKUP_SYSTEM}/opt/adv-opcua/*.der
}

umount -f ${EMMC_DEVICE_NODE}p3
mkdir -p $ABS_DIR_SYSTEM
mount ${EMMC_DEVICE_NODE}p3 $ABS_DIR_SYSTEM
echo "${EMMC_DEVICE_NODE}p3 $ABS_DIR_SYSTEM"

# backup file 
if [ "$2" = "-c" ] ; then
    psplash_progress 5 && psplash_message "start Copy file system and make rootfs.zstd"
  
    [[ -e ${ABS_BACKUP_SYSTEM} ]] && rm -rf ${ABS_BACKUP_SYSTEM}
    mkdir -p ${ABS_BACKUP_SYSTEM}     

    echo "start copy $ABS_DIR_SYSTEM/* $ABS_BACKUP_SYSTEM/"	
    
    [[ -f "$ABS_ZSTD_OUT_FILE" ]] && rm -f $ABS_ZSTD_OUT_FILE  && echo "delete old rootfs.zstd"
    [[ -f "$ABS_EXT4_OUT_FILE" ]] && rm -f $ABS_EXT4_OUT_FILE  && echo "delete old rootfs.ext4"

    psplash_progress 10  && psplash_message "create backup file"   
    ROOTFS_SIZE=`df -hm  | grep $ABS_DIR_SYSTEM | awk -F ' ' '{print $3}'|   tr -d 'M|G|T'`
    ROOTFS_SIZE_WITH_1M=$(( ${ROOTFS_SIZE}+200 ))
    dd if=/dev/zero of=$ABS_EXT4_OUT_FILE bs=1M count=${ROOTFS_SIZE_WITH_1M}
    sync
    sync
    
    psplash_progress 15  && psplash_message "format backup file"
    mkfs.ext4 $ABS_EXT4_OUT_FILE  1>/dev/null 2>&1 
    RETURN_CODE=$?
    if [ $RETURN_CODE -ne 0 ]; then
         psplash_message "Error! mkfs.ext4  failed" 
         psplash_quit
        sleep 1
        return 1
    fi

    psplash_progress 20  && psplash_message "mounting backup file"
    mount -o loop $ABS_EXT4_OUT_FILE $ABS_BACKUP_SYSTEM 
    RETURN_CODE=$?
    if [ $RETURN_CODE -ne 0 ]; then
        psplash_message "Error! mount rootfs failed"  
        psplash_quit
        sleep 1
        return 1

    fi

    psplash_progress 30  && psplash_message "copy files to mounting folder"
    cp -rf --preserve=all $ABS_DIR_SYSTEM/* $ABS_BACKUP_SYSTEM/
    RETURN_CODE=$?
    if [ $RETURN_CODE -ne 0 ]; then
        psplash_message "Copy files error...."
        psplash_quit
        sleep 1
        return 1
     fi

    psplash_progress 60 && psplash_message "remove old files......"
    remove_files
    echo "BACKUPTIME="$DATE"" >>$ABS_BACKUP_SYSTEM/etc/os-release

    sync
    cd -
    umount -d $ABS_DIR_SYSTEM/
    umount -d $ABS_BACKUP_SYSTEM/
    psplash_progress 80 && psplash_message "compress backup file  start"
    zstd $ABS_EXT4_OUT_FILE  --priority=rt  -0 -f -o $ABS_ZSTD_OUT_FILE
    psplash_progress 90 && psplash_message "compress backup file  done"
    sync 
    rm -rf ${ABS_EXT4_OUT_FILE}
    sleep 1
    psplash_progress 100 && psplash_message "backup system successfully"
    sleep 1
    # rm -rf ${ABS_BACKUP_SYSTEM} 

#restore file
elif [ "$2" = "-r" ]; then 
    psplash_progress 20 && psplash_message "restore files start"
    [[ -e ${ABS_RESTORE_SYSTEM} ]] && rm -rf $ABS_RESTORE_SYSTEM
    mkdir -p $ABS_RESTORE_SYSTEM

    psplash_progress 40 && psplash_message "un-compress files"
    echo "mount $ABS_RESTORE_SYSTEM"
    zstd -d $ABS_ZSTD_OUT_FILE --priority=rt  -0 -f -o $ABS_EXT4_OUT_FILE 
    mount -o loop $ABS_EXT4_OUT_FILE $ABS_RESTORE_SYSTEM

    psplash_progress 50 && psplash_message "restore files......check version"
	EMMC_VERSION=`cat ${ABS_DIR_SYSTEM}/etc/os-release | grep IMAGE_VERSION |awk -F '"' '{print $2}' |  awk -F '-' '{print $NF}'| sed 's/^v//'`
    ls -al $ABS_RESTORE_SYSTEM
	BACKUP_VERSION=`cat ${ABS_RESTORE_SYSTEM}/etc/os-release | grep IMAGE_VERSION |awk -F '"' '{print $2}' |  awk -F '-' '{print $NF}'| sed 's/^v//'` 
	if [ -n "$BACKUP_VERSION" ] && [ -n $EMMC_VERSION ]; then
		if [ "$BACKUP_VERSION" != "$EMMC_VERSION" ]; then
            psplash_message "Error !! The backup system version does not match the system version to be installed "
            psplash_quit
            return 1
        else
            psplash_progress 60 && psplash_message "start remove old files"
            rm -fr ${ABS_DIR_SYSTEM}/*
            psplash_progress 70 && psplash_message "start restore system"
            cp -rf --preserve=all  $ABS_RESTORE_SYSTEM/* $ABS_DIR_SYSTEM/    
            psplash_progress 90 && psplash_message "restore system done"
            rm -rf $ABS_EXT4_ZSTD_FILE
            sync
            sync
        fi
    fi
    
else
    echo "unknown command"
fi

exit 0
