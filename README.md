# MULTItest
automation to drive multiple simultaneous I/O workloads on LVM cached devices.
Supports multiple 'device modes' and 'run modes' to allow comparing performance rates.
  * device-mode  Valid values are: xfshdd; xfsnvme; xfscached
  * run-mode     Valid values are: standalone; isolated; combined

Includes scripts to setup and teardown the devices
NOTE: the runMULTI.sh script assumes that the device setup has previously been run.

