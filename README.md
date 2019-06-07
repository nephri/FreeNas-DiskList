# FreeNas-DiskList
FreeNas "Disklist" script for report informations about installed hard drives

I wrote this script for getting informations about all installed disks inside my FreeNas box.

This script is written in Perl and use under the hood theses commands:
* geom disk list
* gpart list
* gmultipath list
* zpool status
* sas2ircu list
* sas2ircu # display
* sas3ircu list
* sas3ircu # display
* smartctl -A [device]

[Command line usages are available here](../../wiki/Command-Line-usage)

# Examples

```
./disklist.pl
partition  label                                       zpool         device  disk                  size  type  serial                 rpm
-----------------------------------------------------------------------------------------------------------------------------------------
da136p2    gptid/ee5188da-2104-11e6-937f-0cc47a320ec8  freenas-boot  da136   SanDisk Ultra Fit       62  ???   4C531001421128120501   ???
da128p2    gptid/a32d92ef-898d-11e6-92dc-0cc47a320ec8  volBACKUP     da128   ATA Hitachi HUA72302  2000  HDD   YGHGTR4A              7200
da129p2    gptid/a64d2fdb-898d-11e6-92dc-0cc47a320ec8  volBACKUP     da129   ATA Hitachi HUA72302  2000  HDD   YFHLRZ1A              7200
da130p2    gptid/a9830745-898d-11e6-92dc-0cc47a320ec8  volBACKUP     da130   ATA Hitachi HUA72302  2000  HDD   YGGU4MKA              7200
da131p2    gptid/acad4d63-898d-11e6-92dc-0cc47a320ec8  volBACKUP     da131   ATA Hitachi HUA72302  2000  HDD   YGGU5D6A              7200
da132p2    gptid/b00a4e80-898d-11e6-92dc-0cc47a320ec8  volBACKUP     da132   ATA Hitachi HUA72302  2000  HDD   YFGR7ZPC              7200
da133p2    gptid/b35b860a-898d-11e6-92dc-0cc47a320ec8  volBACKUP     da133   ATA Hitachi HUA72302  2000  HDD   YGHHK07A              7200
da134p2    gptid/b6b2f0e7-898d-11e6-92dc-0cc47a320ec8  volBACKUP     da134   ATA Hitachi HUA72302  2000  HDD   YFHHMMXA              7200
da135p2    gptid/ba039608-898d-11e6-92dc-0cc47a320ec8  volBACKUP     da135   ATA Hitachi HUA72302  2000  HDD   YGGK2R4A              7200
```

```
./disklist.pl -i:zpool tank -all

partition  fs           label                                       zpool zpool-location  device  sector  disk                  size  type  serial     rpm  sas-location    multipath  path-mode  path-state
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
da128p2    freebsd-zfs  gptid/a32d92ef-898d-11e6-92dc-0cc47a320ec8  tank  tank/raidz2-0   da128      512  ATA Hitachi HUA72302  2000  HDD   YGHGTR4A  7200  SAS2008(0):2#3
da129p2    freebsd-zfs  gptid/a64d2fdb-898d-11e6-92dc-0cc47a320ec8  tank  tank/raidz2-0   da129      512  ATA Hitachi HUA72302  2000  HDD   YFHLRZ1A  7200  SAS2008(0):2#2

```
