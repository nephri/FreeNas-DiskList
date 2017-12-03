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

# Example
```
./disklist.pl -i:zpool tank -all

partition           label                                       zpool    device     sector  disk                      size  type  serial     rpm  location         multipath         mode
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
multipath/disk30p2  gptid/fe38f700-829a-11e7-810a-00074304a2f0  tank     da49,da97     512  HITACHI HUS72302CLAR2000  2000  HDD   YGH1E3DD  7200  SAS3008(1):3#53  multipath/disk30
multipath/disk31p2  gptid/01a5298c-829b-11e7-810a-00074304a2f0  tank     da50,da98     512  HITACHI HUS72302CLAR2000  2000  HDD   YGH1Y9KD  7200  SAS3008(1):3#54  multipath/disk31
```
