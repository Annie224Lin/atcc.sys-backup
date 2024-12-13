#!/bin/bash

CONTAINER_VER="1.0"
PRODUCT_NAME="swupdate-backup-image"
TIMESTAMP=$(date '+%Y%m%d%H%M%S')
DTB_IMAGE="imx8mm-adv-eamb9918-a1.dtb"
KERNEL_IMAGE="Image"
KERNEL_IMAGE_SHA256="sha256sums"
ROOTFS_EXT4_IMAGE=$1
FIXUP_SCRIPT="fixupdate.sh"
ROOTFS_EXT4_IMAGE="rootfs.ext4"
EMMC_NODE="/dev/mmcblk2"
EMMC_DIR_ROOTFS="/run/media/mmcblk2p3"
EMMC_DIR_KERNEL="/run/media/mmcblk2p1"
SW_CONFIG="sw-description"
SIGN_IMAGE="YES"
ENC_IMAGE=".enc"
LOG_FILE=/run/media/sda1/atcc.sys-backup.log
AES_FILE="aes_key"

if [ ! -d ${EMMC_DIR_ROOTFS} ]; then 
	mkdir -p ${EMMC_DIR_ROOTFS}
	mount ${EMMC_NODE}p3 ${EMMC_DIR_ROOTFS}  1>/dev/null 2>1 
fi

swupdate_get_sha256() {
    local file="$1"
    if [[ -f "$file" ]]; then
        sha256sum "$file" | awk '{ print $1 }'
    else
        echo " $file is missing！" >&2
        return 1
    fi
}

encrypt_file() {

    if [ -z $SIGN_IMAGE ];then 
        return 0 ;
    fi

    local file="$1"    
    echo "start encrypt $file"
    if [ -e ${file} ] ;then
        openssl enc -aes-256-cbc -in "${file}" -out "${file}.enc" -K ${key} -iv ${iv} -nosalt
        if [ ! -e "${file}.enc" ];then
            echo "encrypt ${file} failed"
            exit 1
        fi
        hash=$(swupdate_get_sha256 "${file}.enc")
        #insert data
        sed -i "/filename = \"${file}\"/{
            s/filename = \"${file}\"/filename = \"${file}.enc\"/
            a\
                encrypted = true; \\
                ivt = \"${iv}\"; \\
                sha256 = \"${hash}\"; 

        }" "$SW_CONFIG"
    else
        echo "${file} not exist "
        exit 1
    fi
    echo "encrypt $file successful"
    echo "encrypt $file successful:$(date '+%Y-%m-%d %H:%M:%S')" >> ${LOG_FILE}

}

# check rootfs.ext
if [ $# -lt 1  ]; then
    echo "Usage: $0 -d <rootfs.ext4> -r <priv.pem> -c <ca.crt> -p <passphrase>"
    exit 1
fi

while getopts ":d:r:c:k:p:" opt; do
  case $opt in    
    d)
      ROOTFS_EXT4_IMAGE="$OPTARG"
      ;;
    r)
      PRIV_KEY_PATH="$OPTARG"
      ;;
    c)
      CRT_PATH="$OPTARG"
      ;;   
    p)
      PASSPHRASE="$OPTARG"
      ;;
    e)
      BAKEUP_FILE="$OPTARG"
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$opt requires an argument." >&2
      exit 1
      ;;
  esac
done

if [ -z $PRIV_KEY_PATH ] && [ -z $CRT_PATH ] && [ -z $PASSPHRASE ] ;then
    ENC_IMAGE=""
    SIGN_IMAGE=""
    echo "create swu file without signed images"
    echo "create swu file with signed images:$(date '+%Y-%m-%d %H:%M:%S')" >> ${LOG_FILE}
else    
    echo "create swu file with signed images"
    echo "create swu file with signed images:$(date '+%Y-%m-%d %H:%M:%S')" >> ${LOG_FILE}
fi

if [ ! -z $SIGN_IMAGE ] ;then
    # make sure prinv/ca file ,passphrase exist ,because mkupdateimg.sh only support make swu file
    if [ -z "$PRIV_KEY_PATH" ] || [ -z "$CRT_PATH" ] ;then
        echo "for secure reason , we need private key and  certificate file to make swupdate file ,please import them or create new one "
        exit 1
    fi

    if [ -z "$PASSPHRASE" ] ; then
        echo "passphrase is missing !!! "
	echo "passphrase is missing  :$(date '+%Y-%m-%d %H:%M:%S')" >> ${LOG_FILE}
        exit 1
    fi

    iv=$(openssl rand -hex 16)
	key=$(openssl rand -hex 32)
	MERGED_CONTENT="$key $iv"
	echo "$MERGED_CONTENT" > "${AES_FILE}"		
	echo "${AES_FILE} created"		
    cat ${AES_FILE} | openssl rsautl -sign -inkey $PRIV_KEY_PATH -in - -out ${AES_FILE}.sig -passin pass:$PASSPHRASE
    rm -rf ${AES_FILE}
fi

[ ! -e "sw-description" ] && echo "sw-description is missing" && exit 1
FILES=" "

#modify swupdate version
if [ -a "$EMMC_DIR_ROOTFS/etc/os-release" ]; then
    ORI_VERSION=$(cat $EMMC_DIR_ROOTFS/etc/os-release | grep IMAGE_VERSION |awk -F '"' '{print $2}' |awk -F '-' '{print $NF}' | sed 's/^.//')   
    [ ! -z $SIGN_IMAGE ] && BK_STR="_backup"
    sed -i "/version = /s/\"\([0-9]\.[0-9]\.[0-9]\"\)/\"${ORI_VERSION}+${TIMESTAMP}${BK_STR}\"/g" sw-description
    sed -i "/version = /s/\"\([0-9]\.[0-9]\"\)/\"${ORI_VERSION}+${TIMESTAMP}${BK_STR}\"/g" sw-description
fi

if [ ! -z $SIGN_IMAGE ] ;then
    FILES="${FILES} sw-description.sig"
fi
#find DTB_IMAGE
if [ ! -d ${EMMC_DIR_KERNEL} ]; then 
	mkdir -p ${EMMC_DIR_KERNEL}
	mount ${EMMC_NODE}p1 ${EMMC_DIR_KERNEL}  1>/dev/null 2>&1
fi

if [ -e "$ROOTFS_EXT4_IMAGE" ];then
	echo "generate the rootfs compressed image by zstd type."
	echo "generate the rootfs compressed image by zstd type :$(date '+%Y-%m-%d %H:%M:%S')" >> ${LOG_FILE}
	result=`cat sw-description | grep "rootfs.zstd"`
	[ "x$result" = "x" ] && echo "sw-description is not config rootfs item" && exit 1
	result=`cat sw-description | grep compressed | grep zstd`
	[ "x$result" = "x" ] && echo "sw-description has invalid compressed type for rootfs" && exit 1
	rm -rf rootfs.zstd
	result=`e2label $ROOTFS_EXT4_IMAGE | grep ext`
	[ "x$result" = "x" ] && e2label $ROOTFS_EXT4_IMAGE rootfs  1>/dev/null 2>&1
	zstd $ROOTFS_EXT4_IMAGE  --priority=rt  -0 -f -o rootfs.zstd    1>/dev/null 2>&1
	encrypt_file rootfs.zstd        
    FILES="${FILES} rootfs.zstd${ENC_IMAGE}"
else
	echo "there is no $ROOTFS_EXT4_IMAGE"    >>${LOG_FILE}
	echo "exit , please check error"
	exit 1
fi


if [ -e "$FIXUP_SCRIPT" ];then
    encrypt_file "$FIXUP_SCRIPT"
    FILES="${FILES} ${FIXUP_SCRIPT}${ENC_IMAGE}"
fi

if [ ! -e $KERNEL_IMAGE ]; then
        cp -rf ${EMMC_DIR_KERNEL}/${KERNEL_IMAGE} .
        SHA256_KERNEL=$(sha256sum $KERNEL_IMAGE | awk -F ' ' '{print $1}')
        echo -n $SHA256_KERNEL > ${KERNEL_IMAGE_SHA256}
        encrypt_file $KERNEL_IMAGE_SHA256
        encrypt_file  $KERNEL_IMAGE
        FILES="${FILES} ${KERNEL_IMAGE}${ENC_IMAGE} ${KERNEL_IMAGE_SHA256}${ENC_IMAGE}"
fi

if [ ! -e $DTB_IMAGE ]; then
        cp -rf ${EMMC_DIR_KERNEL}/*.dtb .
        encrypt_file "${DTB_IMAGE}"
        FILES="${FILES} ${DTB_IMAGE}${ENC_IMAGE} "
fi


echo "sw-description is as below:"
cat $SW_CONFIG
#description should be the first of the list
ls $SW_CONFIG | cpio -ov -H crc > ../${PRODUCT_NAME}_${CONTAINER_VER}.swu


echo "sign swu file :$(date '+%Y-%m-%d %H:%M:%S')" >> ${LOG_FILE}
if [ ! -z $SIGN_IMAGE ] ;then
    # sw-description.sig after sw-description
    openssl cms -sign -in  sw-description -out sw-description.sig -signer $CRT_PATH  -inkey $PRIV_KEY_PATH -outform DER -nosmimecap -binary -passin pass:$PASSPHRASE 
fi


echo "[update file list: [$FILES] into swu file  $(date '+%Y-%m-%d %H:%M:%S') ]"  >> $LOG_FILE
for i in $FILES;
do
       echo $i;done |cpio -Aov -H crc -F  ../${PRODUCT_NAME}_${CONTAINER_VER}.swu


if [  -e ../${PRODUCT_NAME}_${CONTAINER_VER}.swu ]; then 
	# copy cetificate and aes_key 
    [ ! -z $SIGN_IMAGE ] && cp -rf $CRT_PATH ${AES_FILE}.sig ../
    echo "[Backup file success]"   >> $LOG_FILE
else
	echo "[Backup file fail]"       >> $LOG_FILE
        exit 1
fi

[ ! -z ${BAKEUP_FILE} ] && cp -rf $BAKEUP_FILE ../ &&   echo "Backup completed. The private key is stored on the USB drive."   >> $LOG_FILE

exit 0
