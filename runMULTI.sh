#!/bin/bash
#----------------------------------------------------------------
# runMULTI.sh - run the various fio jobs on DEVICES using the device-mode
#               passed as $1 and run-mode passed as $2
# EXPECTS TWO PARAMETERs:
#     device-mode
#                 Valid values are: xfshdd; xfsnvme; xfscached
#     run-mode
#                 Valid values are: standalone; isolated; combined
#
# DEPENDENCIES: (must be in search path)
#   I/O workload generator: fio
# 
# ASSUMES the device-mode devices are already mounted.
#    See the 'setup.sh' and 'teardown.sh' scripts.
#    Device name vars used for FIO filename param:
#     - fnameBACKUP, fnameCLIENT, fnamePRIMARY
#
# NOTE caches are dropped prior to each testrun as described here:
#   https://linux-mm.org/Drop_Caches
#----------------------------------------

# Verify valid DEVICEMODE parameter passed
case $1 in
  xfshdd|xfsnvme|xfscached)
      deviceMODE=$1
      ;;
  *)
      echo "USAGE: $0 deviceMODE runMODE"
      echo "$LINENO: unrecognized value for deviceMODE on cmdline"
      echo "Valid values are: xfshdd, xfsnvme, xfscached"
      exit 1
      ;;
esac

# Verify valid RUNMODE parameter passed
case $2 in
  standalone|isolated|combined)
      runMODE=$2
      ;;
  *)
      echo "USAGE: $0 deviceMODE runMODE"
      echo "$LINENO: unrecognized value for runMODE on cmdline"
      echo "Valid values are: standalone, isolated, combined"
      exit 2
      ;;
esac

# Bring in other script files
myPath="${BASH_SOURCE%/*}"
if [[ ! -d "$myPath" ]]; then
    myPath="$PWD" 
fi

# Both DEVICE-MODE and RUN-MODE
# MUST BE SET BEFORE INCLUDING vars.shinc FILE!
# Variables
source "$myPath/vars.shinc"

# Functions
source "$myPath/Utils/functions.shinc"

#--------------------------------------
# Housekeeping
#
# Check dependencies are met
chk_dependencies

# Create log file - named in vars.shinc
if [ ! -d $RESULTSDIR ]; then
  mkdir -p $RESULTSDIR || \
    error_exit "$LINENO: Unable to create RESULTSDIR."
fi
touch $LOGFILE || error_exit "$LINENO: Unable to create LOGFILE."
updatelog "${PROGNAME} - Created logfile: $LOGFILE"

updatelog "${PROGNAME} - deviceMODE is $deviceMODE; runMODE is $runMODE"

#
# END: Housekeeping
#--------------------------------------

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# Pre-TEST SECTION 
############################

#
# Call teardown and then setup.sh ??
#

# Set the fname and runtime/ramptime vars based on deviceMODE
# filename settings for fio runs
if [ "$deviceMODE" = "setup" ] || [ "$deviceMODE" = "teardown" ]; then
  # do nothing
  :
elif [ "$deviceMODE" = "xfshdd" ]; then
  fnameBACKUP="${hddMNT}0"
  fnameCLIENT="${hddMNT}1"
  fnamePRIMARY="${hddMNT}2"
  runtime=$xfshdd_RUNT
  ramptime=$xfshdd_RAMPT
elif [ "$deviceMODE" = "xfsnvme" ]; then
  fnameBACKUP="${nvmeMNT}0"
  fnameCLIENT="${nvmeMNT}1"
  fnamePRIMARY="${nvmeMNT}2"
  runtime=$xfsnvme_RUNT
  ramptime=$xfsnvme_RAMPT
elif [ "$deviceMODE" = "xfscached" ]; then
  fnameBACKUP="${cachedMNT}0"
  fnameCLIENT="${cachedMNT}1"
  fnamePRIMARY="${cachedMNT}2"
  runtime=$xfscached_RUNT
  ramptime=$xfscached_RAMPT
else
  error_exit "$LINENO: invalid value for deviceMODE"
fi

# NOW - adjust the FIO filename locations based on runMODE
if [ "$runMODE" = "setup" ] || [ "$runMODE" = "teardown" ]; then
  # no changes needed
  :
elif [ "$runMODE" = "standalone" ] || [ "$runMODE" = "isolated" ]; then
  # no changes needed
  :
elif [ "$runMODE" = "combined" ]; then
  # adjust FIO filename vars
  fnameBACKUP="${fnamePRIMARY}/backup"
  fnameCLIENT="${fnamePRIMARY}/client"
  fnamePRIMARY="${fnamePRIMARY}/primary"
  fname_arr=( "${fnameBACKUP}" "${fnameCLIENT}" "${fnamePRIMARY}" )
  for dirname in "${fname_arr[@]}"; do
    if [ -d $dirname ]; then
      updatelog "$LINENO: Removing existing dir $dirname"
      rm -rf $dirname
      if [ $? -ne 0 ]; then
        error_exit "$LINENO: unable to rm $dirname"
      fi
    fi
    mkdir $dirname
    if [ $? -ne 0 ]; then
      error_exit "$LINENO: unable to mkdir $dirname"
    fi
  done
else
  error_exit "$LINENO: invalid value for runMODE"
fi

# set the SCRATCH location used by the FIO jobs
scratchBACKUP="${fnameBACKUP}/scratch_backup"
scratchCLIENT="${fnameCLIENT}/scratch_client"
scratchPRIMARY="${fnamePRIMARY}/scratch_primary"

# Calculate runtime for backgrd jobs - ensure they
# stay active for the duration of all the [primary] jobs
numjobs="${#fioJOBS[@]}"
numjobs_adjusted=$(($numjobs - 1))
temp_rt=$(($runtime + $ramptime))
bkgrd_rt=$(($temp_rt * numjobs_adjusted))

# Write runtime environment and key variable values to LOGFILE
print_Runtime

updatelog "${PROGNAME} - preparing to run $numjobs fio jobs"
updatelog "${PROGNAME} > each for $runtime seconds"

# Print summary
echo "deviceMODE is ${deviceMODE} - runMODE is ${runMODE}"
echo "> scratchBACKUP is ${scratchBACKUP} : size ${scratchBACKUP_SZ}"
echo "> scratchCLIENT is ${scratchCLIENT} : size ${scratchCLIENT_SZ}"
echo "> scratchPRIMARY is ${scratchPRIMARY} : size ${scratchPRIMARY_SZ}"

# Write the test area/file for all FIO jobs with random blocks
updatelog "START: Writing a scratch area for each FIO job"
write_scratch $scratchBACKUP $scratchBACKUP_SZ
write_scratch $scratchCLIENT $scratchCLIENT_SZ
write_scratch $scratchPRIMARY $scratchPRIMARY_SZ
updatelog "COMPLETED: Writing the scratch areas"

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# TEST SECTION 
############################
for fiojob in "${fioJOBS[@]}"; do
  # set vars needed for this fiojob
  case $fiojob in
  backup)
      offset="0G"
      fs="30G"
      bs="1024k"
      rw="read"
      ioeng="sync"
      direct=0
      filename="${scratchBACKUP}"
      if [ $runMODE = "isolated" ] || [ $runMODE = "combined" ]; then
        xtraFlags="${backupRATE}"
      else
        xtraFlags=""
      fi
      ;;
  client)
      offset="0G"
      fs="30G"
      bs="4k"
      ioeng="sync"
      direct=1
      filename="${scratchCLIENT}"
#      case $fiojob in
#          clientRR) rw="randread"  ;;
#          clientRW) rw="randwrite"  ;;
#          *) error_exit "$LINENO: unrecognized value for fiojob = $fiojob."
#      esac
      rw="randrw"
      xtraFlags="--rwmixread=80"
#      xtraFlags="--rwmixread=80 --numjobs=4"
      ;;
  primary*)
      bs="64k"
      rw="randread"
      ioeng="libaio"
      direct=1
      filename="${scratchPRIMARY}"
      xtraFlags="--iodepth=16 --overwrite=0"
      case $fiojob in
          primary0G)  offset="0G";  fs="10G" ;;
          primary11G) offset="11G"; fs="21G" ;;
          primary22G) offset="22G"; fs="27G" ;;
          primary28G) offset="28G"; fs="29G" ;;
          *) error_exit "$LINENO: unrecognized value for fiojob = $fiojob."
      esac
      ;;
  *)
      error_exit "$LINENO: unrecognized value for fiojob = $fiojob."
      ;;
  esac

  if [ "$runMODE" = "standalone" ] || [ "$filename" = "$scratchPRIMARY" ]
  then
    res_file="${RESULTSDIR}/${fiojob}_${deviceMODE}.fio"
    if [ -e $res_file ]; then
      rm -f $res_file
    fi

    updatelog "*************************"
    updatelog "STARTING: fio job - $fiojob"
    updatelog "FIO params: OFFSET=$offset; FILESZ=$fs; RW=$rw; BS=$bs; \
        filename=$filename runtime=$runtime ramptime=$ramptime $xtraFlags"

    # ONLY NEEDED FOR fiojob [primary] and deviceMODE=xfscached
    # Output lvmcache statistics prior to this run
    if [ "$deviceMODE" = "xfscached" ] && [ "$filename" = "$scratchPRIMARY" ]
    then
      devmapper=$(df $filename | awk '{if ($1 != "Filesystem") print $1}')
      cacheStats $devmapper start
    fi

    # clear the cache prior to fio job
    sync; echo 3 > /proc/sys/vm/drop_caches

    # issue the fio job and wait for it to complete
    fio --offset=${offset} --filesize=${fs} --blocksize=${bs} --rw=${rw} \
      --ioengine=${ioeng} --direct=${direct} --filename=${filename} \
      --time_based --runtime=${runtime} --ramp_time=${ramptime} \
      --fsync_on_close=1 --group_reporting ${xtraFlags} \
      --name=${fiojob} --output=${res_file} >> $LOGFILE

    if [ ! -e $res_file ]; then
       error_exit "fio job $fiojob failed to: ${filename}"
    fi

    updatelog "COMPLETED: fio job - $fiojob"
    fio_print $res_file

    # ONLY NEEDED FOR fiojob [primary] and deviceMODE=xfscached
    # Output lvmcache statistics after each run
    # these calls should emit delta values
    if [ "$deviceMODE" = "xfscached" ] && [ "$filename" = "$scratchPRIMARY" ]
    then
      devmapper=$(df $filename | awk '{if ($1 != "Filesystem") print $1}')
      cacheStats $devmapper stop
    fi

    echo "FIO output:" >> $LOGFILE
    cat ${res_file} >> $LOGFILE
    updatelog "+++++++++++++++++++++++++++++++++++++++++++++++"
  else
    # runMODE is isolated/combined and FIOJOB is not PRIMARY
    updatelog "*************************"
    updatelog "STARTING as backgrd process: fio job - $fiojob"
    updatelog "FIO params: OFFSET=$offset; FILESZ=$fs; RW=$rw; BS=$bs; \
               filename=$filename runtime=$bkgrd_rt $xtraFlags"

    fio_bkgrd_out="${RESULTSDIR}/${fiojob}_${deviceMODE}.bkgrd"
    if [ -e $fio_bkgrd_out ]; then
      rm -f $fio_bkgrd_out
    fi
    # Issue the fio job as background process
    fio --offset=${offset} --filesize=${fs} --blocksize=${bs} --rw=${rw} \
      --ioengine=${ioeng} --direct=${direct} --filename=${filename} \
      --time_based --runtime=${bkgrd_rt} \
      --fsync_on_close=1 --group_reporting ${xtraFlags} \
      --name=${fiojob} > ${fio_bkgrd_out} &
#      --name=${fiojob} > /dev/null 2>&1 &

  fi               # end IF - standalone OR scratchPRIMARY

done         # end FOR fiojob

###################################################
# Kill any background FIO processes
updatelog "LISTING any leftover background FIO jobs..."
echo "feel free to kill these manually"
ps au | grep fio

pids_pgrep=`echo -n $(pgrep -x fio)`
#pids=$(echo -n $pids_pgrep)
#echo $pids_pgrep
pidpat="^[0-9]*"
if [[ $pids_pgrep =~ $pidpat ]]; then
  updatelog "Background FIO jobs found - killing them now"
  kill $pids_pgrep
else
  updatelog "No background FIO jobs found running"
fi

# Really Done
updatelog "END ${PROGNAME}**********************"
updatelog "${PROGNAME} - Closed logfile: $LOGFILE"
exit 0

