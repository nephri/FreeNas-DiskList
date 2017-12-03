# FreeNas-DiskList
FreeNas "Disklist" script for report informations about installed hard drives

I wrote this script for getting informations about all installed disks inside my FreeNas box.

This script is written in Perl and use under the hood theses commands:
* geom disk list
* gmultipath status
* zpool status
* glabel status
* sas2ircu list
* sas2ircu # display
* sas3ircu list
* sas3ircu # display
* nvmecontrol devlist

[Command line usages are available here](../../wiki/Command-Line-usage)

# Examples

```
./disklist.pl
partition           zpool         device      disk                      size  serial                 rpm
--------------------------------------------------------------------------------------------------------
da134p2             freenas-boot  da134       SanDisk Ultra Fit           62  4C531001421128120501   ???
da126p2             volBACKUP     da126       ATA Hitachi HUA72302      2000  YGHGTR4A              7200
da127p2             volBACKUP     da127       ATA Hitachi HUA72302      2000  YFHLRZ1A              7200
da128p2             volBACKUP     da128       ATA Hitachi HUA72302      2000  YGGU4MKA              7200
da129p2             volBACKUP     da129       ATA Hitachi HUA72302      2000  YGGU5D6A              7200
da130p2             volBACKUP     da130       ATA Hitachi HUA72302      2000  YFGR7ZPC              7200
da131p2             volBACKUP     da131       ATA Hitachi HUA72302      2000  YGHHK07A              7200
da132p2             volBACKUP     da132       ATA Hitachi HUA72302      2000  YFHHMMXA              7200
da133p2             volBACKUP     da133       ATA Hitachi HUA72302      2000  YGGK2R4A              7200
```

```
./disklist.pl -i:zpool tank -all

partition           label                                       zpool    device     sector  disk                      size  type  serial     rpm  location         multipath         mode
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
multipath/disk30p2  gptid/fe38f700-829a-11e7-810a-00074304a2f0  tank     da49,da97     512  HITACHI HUS72302CLAR2000  2000  HDD   YGH1E3DD  7200  SAS3008(1):3#53  multipath/disk30
multipath/disk31p2  gptid/01a5298c-829b-11e7-810a-00074304a2f0  tank     da50,da98     512  HITACHI HUS72302CLAR2000  2000  HDD   YGH1Y9KD  7200  SAS3008(1):3#54  multipath/disk31
```
