# MULTItest
automation to drive multiple simultaneous I/O workloads on LVM cached devices.  
Supports multiple 'device modes' and 'run modes' to allow comparing performance rates.  
  * device-mode  Valid values are: xfshdd; xfsnvme; xfscached
  * run-mode     Valid values are: standalone; isolated; combined

Includes scripts to setup and teardown the devices.  These scripts configure the devices
to be tested. You will want to edit the 'vars.shinc' file variables prior to executing them:
  * slowDEV_arr
  * fastDEV
  * hddDEV_arr
  
Here are the steps to complete a test:
  * edit device and runtime settings in 'vars.shinc'
  * run './setup.sh' as root <-- creates 'LOGFILEsetup'
  * run './runMULTI.sh <device-mode> <run-mode>' as root  <-- creates 'RESULTS/<testname>_<timestamp>' logfile
  * run './teardown.sh' as root <-- creates 'LOGFILEteardown'
  
NOTE: the runMULTI.sh script assumes that the device setup script has previously been run.

