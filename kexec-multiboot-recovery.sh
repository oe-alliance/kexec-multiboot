#! /bin/sh
### BEGIN INIT INFO
# Version:              1.0.0
# Provides:             kexec-multiboot-recovery
# Required-Start:       $local_fs
# Required-Stop:        
# Default-Start:        2 3 4 5
# Default-Stop:         0 1 6
# Short-Description:    Kexec kernel check
### END INIT INFO

DRYRUN=true
DEBUG=false

DESC="Kexec kernel validity check...\n"

STARTUP_PATH=""
STARTUP_PATH=/boot # only for devel, comment out for final test

KEXEC_KERNEL_PATH=/usr/bin/kernel_auto.bin

#Hardcoded partition
do_detect_box() {
    MODEL=`cat /proc/device-tree/bolt/board | tr -d '\000' | tr "[A-Z]" "[a-z]"`
    echo "- Detected $MODEL"
    case $MODEL in
    solo4k|uno4k|ultimo4k)
        KERNEL=mmcblk0p1
        ROOTFS=mmcblk0p4
    ;;
    uno4kse)
        KERNEL=mmcblk0p1
        ROOTFS=mmcblk0p4
    ;;
    zero4k)
        KERNEL=mmcblk0p4
        ROOTFS=mmcblk0p7
    ;;
    duo4k|duo4kse)
        KERNEL=mmcblk0p6
        ROOTFS=mmcblk0p9
    ;;
    *)
        echo "ERROR: this box isn't supported yet"
    ;;
    esac
}

do_locate_current_image(){
    args=`cat ${STARTUP_PATH}/STARTUP`
    for x in ${args};
    do
        case "$x" in
            root=*)
                ROOT_DEST="${x#root=}"
            ;;
            kernel=*)
                KERNEL_DEST="${x#kernel=}"
            ;;
        esac
    done
    [ x${DEBUG} = xtrue ] && echo DEBUG:ROOT_DEST=${ROOT_DEST}
    [ x${DEBUG} = xtrue ] && echo DEBUG:KERNEL_DEST=${KERNEL_DEST}

    if echo ${ROOT_DEST} | grep -qi "UUID="; then
        DEVICE=$(blkid | sed -n "/${ROOT_DEST#*=}/s/\([^:]\+\):.*/\\1/p")
        if [ x${DEVICE} != x ]; then
            ROOT_DEST=`grep "^${DEVICE}" /proc/mounts | cut -d " " -f 2`
        fi
    elif echo ${ROOT_DEST} | grep -q "^/dev/mmcblk"; then
        ROOT_DEST=/boot
    else
        ROOT_DEST=`grep "^${ROOT_DEST}" /proc/mounts | cut -d " " -f 2`
    fi
    [ x${DEBUG} = xtrue ] && echo DEBUG:ROOT_DEST=${ROOT_DEST}
    [ x${DEBUG} = xtrue ] && echo DEBUG:KERNEL_DEST=${KERNEL_DEST}
    SELECTED_KERNEL_PATH=${ROOT_DEST}/${KERNEL_DEST}
}

do_fix() {
    echo "- Backup running kernel into previous selected image"
    cmd="dd if=/dev/$KERNEL of=${SELECTED_KERNEL_PATH}"
    [ x${DRYRUN} = xtrue ] && echo "DRYRUN: ${cmd}" || ${cmd}
    echo "- Restoring kexec multiboot kernel"
    cmd="dd if=/usr/bin/kernel_auto.bin of=/dev/$KERNEL"
    [ x${DRYRUN} = xtrue ] && echo "DRYRUN: ${cmd}" || ${cmd}
    cmd="reboot"
    [ x${DRYRUN} = xtrue ] && echo "DRYRUN: ${cmd}" || ${cmd}
}

do_check() {
    if [ -f ${STARTUP_PATH}/STARTUP -a -f ${STARTUP_PATH}/STARTUP.cpio.gz ]; then
        if [ -f /sys/firmware/devicetree/base/chosen/bootargs ]; then
            echo "- Kexec kernel works correctly"
        else
            echo "- Kexec kernel not running... fixing"
            do_detect_box
            do_locate_current_image
            [ x${DEBUG} = xtrue ] && echo DEBUG:SELECTED_KERNEL_PATH:${SELECTED_KERNEL_PATH}

            if [ x${SELECTED_KERNEL_PATH} != x ]; then
                do_fix
            fi
        fi
    else
        echo "- Kexec multiboot not installed.. no fix needed"
    fi
}

case "$1" in
    start)
        echo -n -e "- $DESC"
        do_check
        echo "done."
        ;;
    *)
        echo "Usage: $0 {start}"
        exit 1
        ;;
esac

exit 0

