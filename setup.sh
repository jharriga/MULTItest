#!/bin/bash
#----------------------------------------------------------------
# setup.sh - create/setup lvm device configuration
# Calls Utils/partitionDEVICES.shinc and Utils/setupCACHES.shinc
#
# Configures the devices, creates the XFS filesystems and mounts the
# filesystems at the mount points, for each of the two device modes,
# listed below.
#
# DEVICE CONFIGURATION:
#   Prepares the devices used for 'mixed I/O' tests.
#   The tests run in one of these three 'device-modes': 
#   XFSHDD:
#     Block devices: /dev/sdh1, /dev/sdi1, /dev/sdj1 (100GB partitions)
#     Mount points:  /mnt/hdd0, hdd1, hdd2 (XFS filesystems)
#   XFSNVME:
#     Block devices: /dev/nvme0n1p1, p2, p3 (100GB partitions)
#     Mount points:  /mnt/nvme0, nvme1, nvme2 (XFS filesystems)
#   XFSCACHED:
#     slowDEV (100GB): /dev/sde, /dev/sdf, /dev/sdg
#     fastDEV (10GB): /dev/nvme0n1p4, p5, p6
#     Block device: /dev/mapper/vg_cache0-lv_cached0
#     Block device: /dev/mapper/vg_cache1-lv_cached1
#     Block device: /dev/mapper/vg_cache2-lv_cached2
#     Mount points: /mnt/cached1, cached2, cached3 (XFS filesystems)
#
#----------------------------------------

# Bring in other script files
myPath="${BASH_SOURCE%/*}"
if [[ ! -d "$myPath" ]]; then
    myPath="$PWD" 
fi

# MANDATORY: set the deviceMODE and runMODE vars
runMODE="setup"
deviceMODE="setup"

# Variables
source "$myPath/vars.shinc"

# Functions
source "$myPath/Utils/functions.shinc"

# Assign LOGFILE
LOGFILE="./LOGFILEsetup"

#--------------------------------------

# check mountpts 
devarr=( "${hddDEV_arr[@]}" "${slowDEV_arr[@]}" "${fastDEV_arr[@]}" )

for dev in "${devarr[@]}"; do
  echo "Checking if ${dev} is in use, if yes abort"
  mount | grep ${dev}
  if [ $? == 0 ]; then
    echo "Device ${dev} is mounted - ABORTING!" 
    echo "User must manually unmount ${dev}"
    exit 1
  fi
done

# Create new log file
if [ -e $LOGFILE ]; then
  rm -f $LOGFILE
fi
touch $LOGFILE || error_exit "$LINENO: Unable to create LOGFILE."
updatelog "$PROGNAME - Created logfile: $LOGFILE"

# PARTITION devices
updatelog "Starting: PARTITION Devices"
source "$myPath/Utils/partitionDEVICES.shinc"
updatelog "Completed: PARTITION Devices"

# SETUP CACHE configuration
updatelog "Starting: DEVICES Setup"
source "$myPath/Utils/setupDEVICES.shinc"
updatelog "Completed: DEVICES Setup"

# Display mount points
echo "HDD mount points"
df -T | grep "${hddMNT}"
echo "NVME mount points"
df -T | grep "${nvmeMNT}"
echo "LVMcached mount points"
df -T | grep "${cachedMNT}"

updatelog "$PROGNAME - END"
echo "END ${PROGNAME}**********************"
exit 0

