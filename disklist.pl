#!/usr/local/bin/perl

use strict;
use warnings;
use POSIX;
#use XML::LibXML;

#==========================================================================
#
#    disklist.pl : Report installed disk output for FreeBsd/FreeNAS
#    Copyright (C) 2017 André Sébastien (sebastien.andre.288@gmail.com), Fort Pierre-Marie
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU Lesser General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU Lesser General Public License for more details.
#
#    You should have received a copy of the GNU Lesser General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#==========================================================================

#
# $devices{'da14'}->{'device'}		da14
# $devices{'da14'}->{'sectorsize'}	512
# $devices{'da14'}->{'disksize'} 	2000398934016
# $devices{'da14'}->{'serial'}		YFH1H5TD
# $devices{'da14'}->{'partitioned'}     0 or 1
# $devices{'da14'}->{'type'}            SSD or HDD or NVME
# $devices{'da14'}->{'rpm'}             7200
# $devices{'da14'}->{'multipath'}       multipath/disk46
# $devices{'da14'}->{'multipath_mode'}  ACTIVE 
# $devices{'da14'}->{'multipath_state'} OPTIMAL 
#
our %devices;
our @devicesKeys;

#
# $partitions{'gptid/fe38f700-829a-11e7-810a-00074304a2f0'}->{'gptid'}		gptid/247b7464-8cba-11e6-b58c-0cc47a320ec8
# $partitions{'gptid/fe38f700-829a-11e7-810a-00074304a2f0'}->{'partition'}	multipath/disk30p2
# $partitions{'gptid/fe38f700-829a-11e7-810a-00074304a2f0'}->{'type'}	        freebsd-zfs
# $partitions{'gptid/fe38f700-829a-11e7-810a-00074304a2f0'}->{'component'}	multipath/disk30
# $partitions{'gptid/fe38f700-829a-11e7-810a-00074304a2f0'}->{'device'}		da97
# $partitions{'gptid/fe38f700-829a-11e7-810a-00074304a2f0'}->{'devices'}	da97,da96
# $partitions{'gptid/fe38f700-829a-11e7-810a-00074304a2f0'}->{'path'}		multipath/disk30
# $partitions{'gptid/fe38f700-829a-11e7-810a-00074304a2f0'}->{'zpool'}		volFAST
# $partitions{'gptid/fe38f700-829a-11e7-810a-00074304a2f0'}->{'zpool_location'} volMAIN/mirror-0
# $partitions{'gptid/fe38f700-829a-11e7-810a-00074304a2f0'}->{'zpool_state'}    ONLINE
#
our %partitions;
our @partitionsKeys; 

# 
# $sasdevices{'YFJ4G2BD'}->{'sas'} 		sas3
# $sasdevices{'YFJ4G2BD'}->{'controller'}	1
# $sasdevices{'YFJ4G2BD'}->{'adapter'}	        SAS2008
# $sasdevices{'YFJ4G2BD'}->{'enclosure'}	3
# $sasdevices{'YFJ4G2BD'}->{'slot'}		55
# $sasdevices{'YFJ4G2BD'}->{'serial'}		YFJ4G2BD
# $sasdevices{'YFJ4G2BD'}->{'protocol'}      	SAS
# $sasdevices{'YFJ4G2BD'}->{'url'}           	sas2-0:1#6
# 
our %sasdevices; 

# arguments
#
our @query_class;
our @query_component;
our @query_fs;
our @query_disktype;
our $accept_smartctl=0;
our $accept_multipath=0;           # 1 = single      ; 2 = multipath    ; 3 = multipath + single
our $accept_multipath_mode=0;      # 1 = passive     ; 2 = active       ; 3 = active + passive
our $output_columns="";
our $output_layout="col"; 

# report output layout
#
our @layout;

sub parseSasDevices { 
   my ($sasircu) = @_;

   for( `$sasircu list | grep '^[ ]*[0-9]'` ) {
      (my $controller,my $adapter) = /^[\s]+([0-9]+)[\s]+([^\s]+)[\s]+.*$/;
     
 
      my $ondisk = 0;
      my $disk;
      for( `$sasircu $controller display ` ) {
         (my $line) = /^(.*)$/;

         if( $line =~ m/^Device is a Hard disk/ ) {
             $ondisk = 1;
             $disk = {};
         }
         if( $ondisk == 1 ) {
             if( $line =~ m/Enclosure/ ) {
                $disk->{'enclosure'} = $line;
                $disk->{'enclosure'} =~ s/^.*:[ ]+([^ ]*).*$/$1/;
             }             
             if( $line =~ m/Slot/ ) {
                $disk->{'slot'} = $line;
                $disk->{'slot'} =~ s/^.*:[ ]+([^ ]*).*$/$1/;
             }             
             if( $line =~ m/Protocol/ ) {
                $disk->{'protocol'} = $line;
                $disk->{'protocol'} =~ s/^.*:[ ]+([^ ]*).*$/$1/;
             }             
             if( $line =~ m/Serial No/ ) {
                $disk->{'serial'} = $line;
                $disk->{'serial'} =~ s/^.*:[ ]+([^ ]*).*$/$1/;
             }             
             if( $line =~ m/Drive Type/ ) {
                $disk->{'type'} = $line;
                $disk->{'type'} =~ s/^.*:[ ]+([^ ]*).*$/$1/;
             }             

             if( $line =~ m/Drive Type/ ) {
                 $disk->{'controller'} = $controller;
                 $disk->{'adapter'}    = $adapter;
                 if( $sasircu eq "sas2ircu" ) {
                    $disk->{'sas'} = "sas2";
                 }
                 if( $sasircu eq "sas3ircu" ) {
                    $disk->{'sas'} = "sas3";
                 }
                 $sasdevices{ $disk->{'serial'} } = $disk;

                 my $url = $adapter . "(" . $controller . "):" . $disk->{'enclosure'} . "#" . $disk->{'slot'};                
                 $disk->{'url'} = $url;

                 $ondisk = 0;
             }
         }
      }
   }
}


sub completeDiskType {
   foreach my $device ( keys %devices ) { 
      if( $device =~ m/^nvd/ ) {
         $devices{ $device }->{'type'}= 'NVME';
      }
      if( $device =~ m/^pmem/ ) {
         $devices{ $device }->{'type'}= 'NVRAM';
      }
   }
}

sub parseMultiPath {
   # multipath/disk3  OPTIMAL  da70 (ACTIVE)
   #                           da22 (PASSIVE)
   my $multipath      = "";
   my $multipathState = "";

   my $inProviders    = 0;
   my $inConsumers    = 0;

   my $disk           = "";
   my $diskMode       = "";

   for( `gmultipath list` ) {
      (my $line) = /^(.*)$/;

      if ( $line =~ m/^Providers:/ ) {
          $inProviders    = 1;
          $inConsumers    = 0;

          $multipath      = "";
          $multipathState = "";

          $disk           = "";
          $diskMode       = "";
      }
      if( $line =~ m/^Consumers:/ ) {
          $inProviders  = 0;
          $inConsumers  = 1;
      }
     
      if( ( $line =~ m/^\d+\.[\s]*Name:/ ) && ( $inProviders == 1 ) ) {
         $multipath =  $line;
         $multipath =~ s/^\d+\.\sName:[\s]*(.*)[\s]*$/$1/;
      }
      if( ( $line =~ m/^[\s]*State:/ ) && ( $inProviders == 1 ) ) {
         $multipathState = $line;
         $multipathState =~ s/^[\s]*State:[\s]*(.*)[\s]*$/$1/;
      }

      if( ( $line =~ m/^\d+\.[\s]*Name:/ ) && ( $inConsumers == 1 ) ) {
         $disk     = $line;
         $disk     =~ s/^\d+\.\sName:[\s]*(.*)[\s]*$/$1/;
         $diskMode = "";
         
         $devices{ $disk }->{'multipath'}       = $multipath;
         $devices{ $disk }->{'multipath_mode'}  = "n/a";
         $devices{ $disk }->{'multipath_state'} = $multipathState; 
      }
      if( ( $line =~ m/^[\s]+State:/ ) && ( $inConsumers == 1 ) ) {
         $diskMode = $line;
         $diskMode =~ s/^[\s]+State:[\s]*(.*)[\s]*$/$1/;
         
         $devices{ $disk }->{'multipath_mode'}  = $diskMode;

         foreach my $gptid ( keys %partitions ) { 
           if( $partitions{ $gptid }->{'component'} eq $multipath ) {
              
              $partitions{ $gptid }->{'path'} = $multipath;
 
              if( $partitions{ $gptid }->{'devices'} eq "" ) {
                $partitions{ $gptid }->{'device'}  = $disk;
                $partitions{ $gptid }->{'devices'} = $disk;
              }
              else {
                $partitions{ $gptid }->{'devices'} = $partitions{ $gptid }->{'devices'} . "," . $disk;
              }
           }
        }
      }
   }

   foreach my $gptid ( keys %partitions ) { 
      if( $partitions{ $gptid }->{'devices'} eq "" ) {
         $partitions{ $gptid }->{'devices'} = $partitions{ $gptid }->{'device'};
      }
   } 
}

sub parseDisks {
   # da70
   #
   my $disk;

   my $device      = "";
   my $type        = "";
   my $description = "";
   my $sectorsize  = "";
   my $rpm         = "";
   my $disksize    = "";
   my $serial      = "";

   for( `geom disk list` ) {
      (my $line) = /^(.*)$/;

      if ( $line =~ m/^Geom name:/ ) {
         $device      = $line;
         $device      =~ s/^.*:[\s]*(.*)[\s]*$/$1/;
         $type        = "";
         $description = "";
         $sectorsize  = "";
         $rpm         = "";
         $disksize    = "";
         $serial      = "";

         $disk  = {};
         $disk->{ 'device'          } = $device;
         $disk->{ 'type'            } = "";
         $disk->{ 'description'     } = "";
         $disk->{ 'sectorsize'      } = "";
         $disk->{ 'rpm'             } = "";
         $disk->{ 'temperature'     } = "";
         $disk->{ 'disksize'        } = "";
         $disk->{ 'serial'          } = "";
         $disk->{ 'partitioned'     } = 0;
         $disk->{ 'multipath'       } = "";
         $disk->{ 'multipath_mode'  } = "";
         $disk->{ 'multipath_state' } = "";

         $devices{ $device } = $disk;
      }
      if ( $line =~ m/^Consumers:/ ) {
         $device      = "";
         $type        = "";
         $description = "";
         $sectorsize  = "";
         $rpm         = "";
         $disksize    = "";
         $serial      = "";
      }
      if ( $line =~ m/^[\s]*descr:/ ) {
         $description =  $line;
         $description =~ s/^.*:[\s]*(.*)[\s]*$/$1/;
         if ( $device ne "" ) { $disk->{ 'description' } = $description; }
      }
      if ( $line =~ m/^[\s]*Sectorsize:/ ) {
         $sectorsize =  $line;
         $sectorsize =~ s/^.*:[\s]*(.*)[\s]*$/$1/;
         if ( $device ne "" ) { $disk->{ 'sectorsize' } = $sectorsize; }
      }
      if ( $line =~ m/^[\s]*rotationrate:/ ) {
         $rpm =  $line;
         $rpm =~ s/^.*:[\s]*(.*)[\s]*$/$1/;
         if ( $device ne "" ) { 
           $disk->{ 'rpm' } = $rpm; 
           if ( $rpm =~ m/^[0-9]+$/ ) {
              if( $rpm > 0 ) { 
                 $disk->{ 'type' } = "HDD";
              }
              else {
                 $disk->{ 'type' } = "SSD";
              }
           }
           else {
              $disk->{ 'type' } = "???";
              $disk->{ 'rpm' }  = "???";
           }
         }
      }
      if ( $line =~ m/^[\s]*Mediasize:/ ) {
         $disksize =  $line;
         $disksize =~ s/^.*:[\s]*([0-9]*)[\s]*.*$/$1/;
         if ( $device ne "" ) { $disk->{ 'disksize' } = $disksize; }
      }
      if ( $line =~ m/^[\s]*ident:/ ) {
         $serial =  $line;
         $serial =~ s/^.*:[\s]*(.*)[\s]*$/$1/;
         if ( $device ne "" ) { $disk->{ 'serial' } = $serial; }
      }
   }
}

sub parsePartitions {
   my $inProviders  = 0;
   my $inConsumers  = 0;

   my $part       = "";
   my $gptid      = "";
   my $type       = "";
   my $component  = "";

   my %providers;

   for( `gpart list` ) {
      (my $line) = /^(.*)$/;

      if ( $line =~ m/^Providers:/ ) {
          $inProviders  = 1;
          $inConsumers  = 0;
      }
      if( $line =~ m/^Consumers:/ ) {
          $inProviders  = 0;
          $inConsumers  = 1;

         if ( $part ne "" ) {
             $providers{ $gptid }->{'gptid'}     = $gptid;         
             $providers{ $gptid }->{'partition'} = $part;         
             $providers{ $gptid }->{'type'}      = $type;         
         }

         $part       = "";
         $gptid      = "";
         $type       = "";
         $component  = "";
      }
     
      if( ( $line =~ m/^\d+\.[\s]*Name:/ ) && ( $inProviders == 1 ) ) {
         if ( $part ne "" ) {
             $providers{ $gptid }->{'gptid'}     = $gptid;         
             $providers{ $gptid }->{'partition'} = $part;         
             $providers{ $gptid }->{'type'}      = $type;         
         }
 
         $part      =  $line;
         $part      =~ s/^\d+\.\sName:[\s]*(.*)[\s]*$/$1/;
         $gptid     = "";
         $type      = "";
         $component = "";
      }
      if( ( $line =~ m/^[\s]*rawuuid:/ ) && ( $inProviders == 1 ) ) {
         $gptid = $line;
         $gptid =~ s/^[\s]*rawuuid:[\s]*(.*)[\s]*$/$1/;
         $gptid = "gptid/" . $gptid;
      }
      if( ( $line =~ m/^[\s]*type:/ ) && ( $inProviders == 1 ) ) {
         $type = $line;
         $type =~ s/^[\s]*type:[\s]*(.*)[\s]*$/$1/;

         if( $type =~ m/^!/ ) {
            $type = "unknown";
         }
      }

      if( ( $line =~ m/^\d+\.\sName:/ ) && ( $inConsumers == 1 ) ) {
         $component =  $line;
         $component =~ s/^\d+\.\sName:[\s]*(.*)[\s]*$/$1/;

         foreach my $p ( keys %providers ) { 
           $providers{ $p }->{'component'} = $component;         

           $partitions{ $p } = $providers{ $p };
           $partitions{ $p }->{'device'}         = "";
           $partitions{ $p }->{'devices'}        = "";
           $partitions{ $p }->{'zpool'}          = "";
           $partitions{ $p }->{'zpool_location'} = "";
           $partitions{ $p }->{'zpool_state'}    = "";
           $partitions{ $p }->{'path'}           = "";

           if( exists( $devices{ $component } ) ) {
 
               $devices{ $component }->{'partitioned'} = 1;
               $partitions{ $p }->{'device'}  = $component;
           }
         }
         undef %providers;

         $inConsumers = 0;
      }
   }
}

sub printPartitions {
   foreach my $p ( keys %partitions ) { 
      print "Partition      : $partitions{ $p }->{'partition'}\n";
      print "   gptid       : $partitions{ $p }->{'gptid'}\n";
      print "   type        : $partitions{ $p }->{'type'}\n";
      print "   comp        : $partitions{ $p }->{'component'}\n";
      print "   device      : $partitions{ $p }->{'device'}\n";
      print "   devices     : $partitions{ $p }->{'devices'}\n";
      print "   path        : $partitions{ $p }->{'path'}\n";
      print "   zpool       : $partitions{ $p }->{'zpool'}\n";
      print "   zpool state : $partitions{ $p }->{'zpool_state'}\n";
      print "\n";
   }
}

sub parseZpools {
   my $zpool = "";
   my $state = "";
   my @hierarchy;

   for( `zpool status` ) {
      (my $line) = /^(.*)$/;

      if ( $line =~ m/^[\s]*pool:/ ) {
         $zpool =  $line;
         $zpool =~ s/^[\s]*pool:[\s]*(.*)[\s]*$/$1/;
         next;
      }

      if ( $line =~ m/^[\s]*state:/ ) {
         $state =  $line;
         $state =~ s/^[\s]*state:[\s]*(.*)[\s]*$/$1/;
         next;
      }
      
      if ( $line =~ m/^[\s]+NAME[\s]+STATE[\s]+/ ) {
         next;
      }

      if( $line =~ m/^\t/ ) {
         # ok, line to handle
      } 
      else {
         next;
      }

      my $whites = $line;
         $whites =~ s/^([\s]+)[^\s]+.*$/$1/; 
      my $level  = ( length( $whites ) - 1 ) / 2;
 
      my $item = $line;
         $item =~ s/^[\s]*([^\s]+)[\s]*.*$/$1/;

      splice @hierarchy , $level , scalar( @hierarchy ) , ( $item );

      my $location = "";
      foreach my $x ( @hierarchy ) {
        if( $x eq $item ) {
           next;
        }
        if( $location eq "" ) {
           $location = $x;
        }
        else {
           $location = $location . "/" . $x;
        }
      }

      if ( $item =~ m/^gptid\// ) {
         my $gptid = $item;

         if( exists( $partitions{ $gptid } ) ) {
            $partitions{ $gptid }->{'zpool'}          = $zpool;
            $partitions{ $gptid }->{'zpool_location'} = $location;
            $partitions{ $gptid }->{'zpool_state'}    = $state;
         }
      }
      else {
         my $part = $item;

         foreach my $gptid ( keys %partitions ) { 
            if( $partitions{ $gptid }->{'partition'} eq $part ) {
               $partitions{ $gptid }->{'zpool'}          = $zpool;
               $partitions{ $gptid }->{'zpool_location'} = $location;
               $partitions{ $gptid }->{'zpool_state'}    = $state;
            }
         }
      }
   }
}

sub parseSmartctlDevice {
   my ($dev) = @_;

   my $idev   = $devices{ $dev };
   my $tmp    = "";
   for( `smartctl -A /dev/$dev` ) {
      (my $line) = /^(.*)$/;
      if ( $line =~ m/^190 / ) {
         $tmp = (split ' ', $line)[9];
      }
      else {
         if ( ( $line =~ m/^194 / ) && ( "$tmp" eq "" ) ) {
            $tmp = (split ' ', $line)[9];
         }
         else {
            if ( $line =~ m/^Current Drive Temperature:/ ) {
               $tmp = (split ' ', $line)[3];
            }
            else {
               # do nothing
            }
        }
      }
   }

   if ( $tmp eq "" ) {
      $tmp = "???"
   }

   $idev->{'temperature'} = $tmp;
}


sub printHelp() {
    print "disklist.pl [-i:<class> <entity>]* [-fs:<fstype>]* [-disk:<disktype>]* [-multi[:<multitype>] [-o:<otype>] [-c:<columns>]* [-all] [-long] [-short] [-smartctl] [-h]\n";
    print "   version 1.1\n";
    print "\n";
    print "   List informations of detected disks from a single command by grabbing and merging theses informations from multiples standard FreeBSD tools:\n";
    print "            > geom disk list\n";
    print "            > gpart list\n";
    print "            > gmultipath list\n";
    print "            > zpool status\n";
    print "            > sas2ircu list\n";
    print "                 > sas2ircu # display\n";
    print "            > sas3ircu list\n";
    print "                 > sas3ircu # display\n";
    print "            > smartctl -A <device>\n";
    print "\n";
    print "   This program comes with ABSOLUTELY NO WARRANTY.\n";
    print "   This is free software, and you are welcome to redistribute it under certain conditions (cf. GNU Lesser General Public Licence v3)\n"; 
    print "\n";
    print "   Arguments are followings:\n";
    print "\n";
    print "   -i:<class> <entity> \n";
    print "          Filter devices/partitions that matches the specified <entity> on the corresponding <class>\n";
    print "          Classes are:\n";
    print "             dev       : Filter on a device name             (exemple: -i:dev ada0)\n";
    print "             zpool     : Filter on a ZFS pool name           (exemple: -i:zpool tank)\n";
    print "             part      : Filter on a partition name          (exemple: -i:part ada0p1)\n";
    print "             gptid     : Filter on a glabel name             (exemple: -i:gptid gptid/fe38f700-829a-11e7-810a-00074304a2f0)\n";
    print "             serial    : Filter on a Disk Serial number      (exemple: -i:serial YFJ4G2BD)\n";
    print "             multipath : Filter on a SAS multipath disk name (exemple: -i:multipath multipath/disk1)\n";
    print "             enclosure : Filter on a SAS enclosure location  (exemple: -i:enclosure 1#6), you can specify <enclosure> or <enclosure>#<slot>\n";
    print "\n";
    print "          This argument can be set multiples times for specifying multiples filters.\n";
    print "\n";
    print "          Be careful, evaluation are done with this logical form :\n";
    print "                     ( device_predicate1 OR device_predicate2 OR ... ) AND ( partition_predicate1 OR partition_predicate2 .... )\n";
    print "\n";
    print "                      devices    predicates are : dev, multipath, serial, enclosure\n";
    print "                      partitions predicates are : zpool, part, gptid\n";
    print "\n";
    print "   -fs:<fstype>\n";
    print "          Filter devices/partitions that have a partition that match the specified file system type\n";
    print "          FileSystem types are:\n";
    print "             none      : The disk must not be partitioned.                                 (exemple: -fs:none)\n";
    print "             all       : Accept any               partition type and disk not partitioned. (exemple: -fs:all)\n";
    print "             any       : Accept any               partition type.                          (exemple: -fs:any)\n";
    print "             zfs       : Accept only freebsd-zfs  partition type.                          (exemple: -fs:zfs)\n";
    print "             swap      : Accept only freebsd-swap partition type.                          (exemple: -fs:swap)\n";
    print "             boot      : Accept only bios-boot    partition type.                          (exemple: -fs:boot)\n";
    print "             unknown   : Accept only unknown      partition type.                          (exemple: -fs:unknown)\n";
    print "\n";
    print "          This argument can be set multiples times for specifying a list of fs type\n";
    print "          By default this command use theses options : -fs:zfs -fs:none\n";
    print "\n";
    print "   -disk:<disktype>\n";
    print "          Filter devices/partitions that match the specified disk type\n";
    print "          Disk types are:\n";
    print "             sdd       : Solid State Drive       (exemple: -disk:ssd)\n";
    print "             hdd       : Spindle Drive           (exemple: -disk:hdd)\n"; 
    print "             nvme      : NVME Solid State Drive  (exemple: -disk:nvme)\n"; 
    print "             nvram     : NVRAM Drive             (exemple: -disk:nvram)\n"; 
    print "             unknown   : Untyped Drive           (exemple: -disk:unknown)\n"; 
    print "\n";
    print "          This argument can be set multiples times for specifying a list of disk type\n";
    print "\n";
    print "   -multi[:<mode>]\n";
    print "          Filter devices/partitions that use SAS multipath and optionaly match the multipath mode (ACTIVE or PASSIVE)\n";
    print "          Multipath modes are:\n";
    print "             none      : The disk device must not use SAS multipath                           (exemple: -multi:none)\n";
    print "             active    : The disk device must     use SAS multipath and be the ACTIVE  device (exemple: -multi:active)\n";
    print "             passive   : The disk device must     use SAS multipath and be the PASSIVE device (exemple: -multi:passive)\n";
    print "\n";
    print "          If no Multipath mode is specified, the disk device must use SAS multipath, whatever the mode of the device.\n";
    print "\n";
    print "   -o:<otype>\n";
    print "          Output format to use for reporting devices.\n";
    print "          Output formats are:\n";
    print "             col       : Each devices are reported in a dedicated row.  Informations are padded with whitespace into columns and columns are separated by 2 whitespaces.\n";
    print "             csv       : Each devices are reported in a dedicated row.  Columns are separated by a semi-colon accordingly to CSV format without any padding.\n";
    print "             list      : Each devices are reported in   multiples rows. Each informations are dedicated on a row using the format \"property: value\".\n";
    print "\n";
    print "         If ommited, this command consider -o:col\n";
    print "\n";
    print "   -c:<columns>\n";
    print "          Specify a serie of columns to report represented by <columns>. Each columns have a symbol identifier.\n";
    print "          The appearence order of a symbol identifier determine the appearance order of the column in the report output.\n";
    print "          Columns identifiers are:\n";
    print "             p         : Partition name                 (exemple: ada0p1)\n";
    print "             P         : Partition type.                (exemple: freebsd-zfs)\n";
    print "             l         : Partition label (gptid).       (exemple: gptid/fe38f700-829a-11e7-810a-00074304a2f0)\n";
    print "             z         : ZFS pool name                  (exemple: tank)\n";
    print "             Z         : Partition location on the pool (exemple: tank/mirror-0)\n";
    print "\n";
    print "             d         : device code                    (exemple: ada0)\n";
    print "             t         : device sectorsize in Bytes     (exemple: 512)\n";
    print "\n";
    print "             D         : Disk Description               (exemple: HITACHI HUS72302CLAR2000)\n";
    print "             U         : Disk size in Gb                (exemple: 2000)\n";
    print "             T         : Disk type                      (exemple: SSD)\n";
    print "             S         : Disk Serial Number             (exemple: YFJ4G2BD)\n";
    print "             R         : Disk Rotational Rate           (exemple: 7200)\n";
    print "             H         : Disk Temperature (smartctl)    (exemple: 43°)\n";
    print "\n";
    print "             e         : Controller/Enclosure location  (exemple: SAS3008(0):1#6)\n";
    print "\n";
    print "             m         : SAS Multipath device           (exemple: multipath/disk1)\n";
    print "             o         : SAS Multipath device mode      (exemple: ACTIVE or PASSIVE)\n";
    print "             s         : SAS Multipath state            (exemple: OPTIMAL)\n";
    print "\n";
    print "          Columns using \"smartctl\" will be reported only if the -smartctl switch is used.\n";
    print "\n";
    print "          You can use -short, -long or -all switches in addition for setting a columns profil + specified columns.\n";
    print "          In this case, the column order is the columns from the profil and after specified columns.\n";
    print "          If a column identifier appear more than one time, the column will be reported the same number of time.\n";
    print "\n";
    print "    -all\n";
    print "          Reports all columns. It's equivalent to -c:pPlzZdtDUTSRHemos\n";
    print "          Can be used in conjunction than -c: switch to add some columns to the -all profile.\n";
    print "\n";
    print "    -long\n";
    print "          Reports with most of columns (but omit fews). It's equivalent to -c:plzdDUTSRH\n";
    print "          It's the default layout of columns if the user didn't specify it.\n";
    print "          Can be used in conjunction than -c: switch to add some columns to the -long profile.\n";
    print "\n";
    print "    -short\n";
    print "          Reports with a base of columns. It's equivalent to -c:pzdDUT\n";
    print "          Can be used in conjunction than -c: switch to add some columns to the -long profile.\n";
    print "\n";
    print "    -smartctl\n";
    print "          Allow the use of \"smartctl\" commands for providing some disk informations\n";
    print "          Without this switch used, columns that need smartctl will be missing on output\n";
    print "    -h\n";
    print "          Print this help.\n";
    print "\n";
}

sub parseArgumentsDiskList {
   my @arguments = @_;
   my $args_state=0;                 # 0 = none        ; 1 = query entity ;
   foreach my $arg ( @arguments ) { 
      if ( $args_state == 1 ) {
          push @query_component , $arg;
   
          $args_state      = 0;
          next;
      }

      if ( $arg =~ m/^-i:.*$/ ) {
          my $c = $arg;
          $c =~ s/^-i:(.*)$/$1/;

          if( $c eq "" ) {
             print "$0 : Bad usage using -i:<class>\n";
             exit 1;
          }

          push @query_class , $c;

          $args_state  = 1; 
          next;
      }
  
      if ( $arg =~ m/^-c:.*$/ ) {
          my $x = $arg;
             $x =~ s/^-c:(.*)$/$1/;

          if( $x eq "" ) {
             print "$0 : Bad usage using -x:<columns>\n";
             exit 1;
          }

          $output_columns = $output_columns . $x;
           
          next;
      }
 
      if ( $arg =~ m/^-o:.*$/ ) {
          $output_layout = $arg;
          $output_layout =~ s/^-o:(.*)$/$1/;
          next;
      }

      if ( $arg eq "-all" ) {
          $output_columns = "pPlzZdtDUTSRHemos" . $output_columns;
          next;
      }
      if ( $arg eq "-long" ) {
          $output_columns = "plzdDUTSRH" . $output_columns;
          next;
      }
      if ( $arg eq "-short" ) {
          $output_columns = "pzdDUT" . $output_columns;
          next;
      }
      if ( $arg eq "-smartctl" ) {
          $accept_smartctl=1;
          next;
      }

      if ( $arg eq "-multi" ) {
          $accept_multipath      = $accept_multipath      | 2;
          next;
      }
      if ( $arg eq "-multi:none" ) {
          $accept_multipath      = $accept_multipath      | 1;
          next;
      }
      if ( $arg eq "-multi:active" ) {
          $accept_multipath      = $accept_multipath      | 2;
          $accept_multipath_mode = $accept_multipath_mode | 2;
          next;
      }
      if ( $arg eq "-multi:passive" ) {
          $accept_multipath      = $accept_multipath      | 2;
          $accept_multipath_mode = $accept_multipath_mode | 1;
          next;
      }


      if ( $arg =~ m/^-fs:.*$/ ) {
          my $fs_type = $arg;
          $fs_type = $arg;
          $fs_type =~ s/^-fs:(.*)$/$1/;

          if( $fs_type eq "" ) {
             print "$0 : Bad usage using -fs:<fs_type>\n";
             exit 1;
          }

          push @query_fs , $fs_type;
          next;
      }

      if ( $arg =~ m/^-disk:.*$/ ) {
          my $disk_type = $arg;
          $disk_type =~ s/^-disk:(.*)$/$1/;
          $disk_type = uc $disk_type;

          if( $disk_type eq "UNKNOWN" ) {
            $disk_type = "???"
          }

          if( $disk_type eq "" ) {
             print "$0 : Bad usage using -disk:<disk_type>\n";
             exit 1;
          }

          push @query_disktype , $disk_type;
          next;
      }

      if ( $arg eq "-h" ) {
          printHelp;
          exit 0;
      }

      print "$0 : Bad usage, unrecognized argument \"$arg\"\n";
      print "$0 : Use -h flag for more details.\n";
      exit 1;
   }

   if( scalar @query_fs == 0 ) {
     @query_fs = ( "zfs" , "none" );
   }
   if( $output_columns eq "" ) {
     $output_columns = "plzdDUTSRH" . $output_columns;
   }
   if( $accept_smartctl == 0 ) {
     $output_columns =~ tr/H//d;
   }
   if( $accept_multipath == 0 ) {
      $accept_multipath = 3;
   }
   if( $accept_multipath_mode == 0 ) {
      $accept_multipath_mode = 3;
   }
   if( $args_state > 0 ) {
      print "$0 : Bad usage, missing argument.\n";
      print "$0 : Use -h flag for more details.\n";
      exit 2;
   }
}


sub applyFilterMultipathMode {
   my ($idev) = @_;
   if( ( $accept_multipath_mode & 1 ) == 0 && $idev->{'multipath_mode'} eq "PASSIVE" ) {
      return 0;
   }
   if( ( $accept_multipath_mode & 2 ) == 0 && $idev->{'multipath_mode'} eq "ACTIVE" ) {
      return 0;
   }
   return 1;
}

sub applyFilterDevice {
   my ($idev) = @_;

   if( ( $accept_multipath & 1 ) == 0 && $idev->{'multipath'} eq "" ) {
      return 0;
   }
   
   if( ( $accept_multipath & 2 ) == 0 && $idev->{'multipath'} ne "" ) {
      return 0;
   }
   if( $idev->{'multipath'} ne "" && $idev->{'partitioned'} == 0 ) {
      if( ( $accept_multipath_mode & 1 ) == 0 && $idev->{'multipath_mode'} eq "PASSIVE" ) {
         return 0;
      }
      if( ( $accept_multipath_mode & 2 ) == 0 && $idev->{'multipath_mode'} eq "ACTIVE" ) {
         return 0;
      }
   }
   #if( ( $accept_partitioned & 1 ) == 0 && $idev->{'partitioned'} == 0 ) {
      #return 0;
   #}
   #if( ( $accept_partitioned & 2 ) == 0 && $idev->{'partitioned'} == 1 ) {
      #return 0;
   #}

   if( scalar @query_disktype == 0 ) {
   }
   else {
      my $ok = 0;
      foreach my $dt ( @query_disktype ) { 
         if( $idev->{'type'} eq $dt ) {
            $ok = 1; 
         }
      }
      if( $ok == 0 ) {
         return 0;
      }
   }

   if( scalar @query_class == 0 ) {
       # do nothing
   }
   else {
      my $ok       = 0;
      my $index    = -1;
      my $comp     = "";
      my $classdev = 0;
      foreach my $class ( @query_class ) {
         $index = $index + 1;
         $comp  = $query_component[ $index ];

         if( ( $class eq "dev" ) || ( $class eq "multipath" ) || ( $class eq "serial" ) || ( $class eq "enclosure" ) ) {
            $classdev = 1;
         }
 
         if( ( $class eq "dev" ) && ( $comp eq $idev->{'device'} ) ) {
            $ok = 1;
         }

         if( ( $class eq "multipath" ) && ( $comp eq $idev->{'multipath'} ) ) {
            $ok = 1;
         }

         if( ( $class eq "serial" ) && ( $comp eq $idev->{'serial'} ) ) {
            $ok = 1;
         }

         if( ( $class eq "enclosure" ) ) {
            if( exists( $sasdevices{ $idev->{'serial'} } ) ) {
               if( $comp =~ m/#/ ) {
                  my $enc  = $comp;
                  my $slot = $comp;
        
                  $enc  =~ s/^([^#]+)#[^#]+$/$1/;
                  $slot =~ s/^[^#]+#([^#]+)$/$1/;

                  my $ok_enclosure = 0;
                  my $ok_slot      = 0;
                  if( $enc eq $sasdevices{ $idev->{'serial'} }->{'enclosure'} ) {
                     $ok_enclosure = 1;
                  }
                  if( $slot eq $sasdevices{ $idev->{'serial'} }->{'slot'} ) {
                     $ok_slot = 1;
                  }

                  if( $ok_enclosure == 1 && $ok_slot == 1 ) {
                     $ok = 1;
                  }
               } 
               else {
                  if( $comp eq $sasdevices{ $idev->{'serial'} }->{'enclosure'} ) {
                     $ok = 1;
                  }
               }
            }
         }
      }
      if( $ok == 0 && $classdev == 1 ) {
         return 0;
      }
   }

   return 1;
}

sub applyFilterLabel {
   my ($ilabel) = @_;

   if( scalar @query_class == 0 ) {
       # do nothing
   }
   else {
      my $ok         = 0;
      my $index      = -1;
      my $comp       = "";
      my $classpart  = 0;
      foreach my $class ( @query_class ) {
         $index = $index + 1;
         $comp  = $query_component[ $index ];

         if( ( $class eq "gptid" ) || ( $class eq "part" ) || ( $class eq "zpool" ) ) {
            $classpart = 1;
         }

         if( $class eq "gptid" ) {
             if( $ilabel eq "" ) {
                # do nothing
             }
             elsif( $comp eq $ilabel->{'gptid'} ) {
                $ok = 1;
             }
         } 

         if( $class eq "part" ) {
             if( $ilabel eq "" ) {
                # do nothing
             }
             elsif( $comp eq $ilabel->{'partition'} ) {
                $ok = 1;
             }
         } 

         if( $class eq "zpool" ) {
             if( $ilabel eq "" ) {
                # do nothing
             }
             elsif( $comp eq $ilabel->{'zpool'} ) {
                $ok = 1;
             }
         } 
      }
      if( $ok == 0 && $classpart == 1 ) {
         return 0;
      }
   }

   if( $ilabel eq "" ) {
      my $ok = 0;
      foreach my $fs ( @query_fs ) { 
         if( ( $fs eq "all" ) || ( $fs eq "none" ) ) {
           $ok = 1;
         }
      }

      if( $ok == 0 ) {
         return 0;
      }
   }
   else {
      my $ok = 0;
      foreach my $fs ( @query_fs ) { 
         if( ( $fs eq "all" ) || ( $fs eq "any" ) ) {
           $ok = 1;
         }
         elsif( $fs eq "zfs" ) {
           if( $ilabel->{'type'} eq "freebsd-zfs" ) {
              $ok = 1;
           }
         }
         elsif( $fs eq "swap" ) {
           if( $ilabel->{'type'} eq "freebsd-swap" ) {
              $ok = 1;
           }
         }
         elsif( $fs eq "boot" ) {
           if( $ilabel->{'type'} eq "bios-boot" ) {
              $ok = 1;
           }
         }
         else {
           if( $ilabel->{'type'} eq $fs ) {
              $ok = 1;
           }
         }
      }

      if( $ok == 0 ) {
         return 0;
      }
   }

   return 1;
}

sub compare_components {
   my ($a,$b) = @_;
   if( ( $a =~ m/[0-9]$/ ) && ( $b =~ m/[0-9]$/ ) ) {
     my $pa = $a;
     my $ia = $a;
     $pa =~ s/^(.*?)([0-9]+)$/$1/;
     $ia =~ s/^(.*?)([0-9]+)$/$2/;

     my $pb = $b;
     my $ib = $b;
     $pb =~ s/^(.*?)([0-9]+)$/$1/;
     $ib =~ s/^(.*?)([0-9]+)$/$2/;

     if( $pa eq $pb ) {
        return $ia <=> $ib;
     }
     return $pa cmp $pb;
   }
   return $a cmp $b;
}

# sort
#  zpool , multipath , multipath_status , device, partition
sub compare_labels {
   my ($a,$b) = @_;

   my $labelA = $partitions{ $a }; 
   my $labelB = $partitions{ $b }; 

   if ( $labelA->{'zpool'} ne $labelB->{'zpool'} ) {
      return $labelA->{'zpool'} cmp $labelB->{'zpool'};
   }

   my $multiA = $devices{ $labelA->{'device'} }->{'multipath'};
   my $multiB = $devices{ $labelB->{'device'} }->{'multipath'};
   if( $multiA ne $multiB ) {
      return compare_components( $multiA , $multiB );
   }

   my $multiModeA = $devices{ $labelA->{'device'} }->{'multipath_mode'};
   my $multiModeB = $devices{ $labelB->{'device'} }->{'multipath_mode'};
   if ( $multiModeA ne $multiModeB ) {
      return $multiModeA cmp $multiModeB;
   }

   if( $labelA->{'device'} ne $labelB->{'device'} ) {
      return compare_components( $labelA->{'device'} , $labelB->{'device'} );
   }
   return $labelA->{'partition'} cmp $labelB->{'partition'};
}

sub compare_devices {
   my ($a,$b) = @_;

   my $multiA = $devices{ $a }->{'multipath'};
   my $multiB = $devices{ $b }->{'multipath'};
   if( $multiA ne $multiB ) {
      return compare_components( $multiA , $multiB );
   }

   my $multiModeA = $devices{ $a }->{'multipath_mode'};
   my $multiModeB = $devices{ $b }->{'multipath_mode'};
   if( $multiModeA ne $multiModeB ) {
      return $multiModeA cmp $multiModeB;
   }

   return compare_components( $a , $b );
}

sub prepareOutputLayout {
   my ($display_columns) = @_;
   undef(@layout);

   my $ocol;
   foreach my $col (split //, $display_columns) {
      my $owner    = "";
      my $info     = "";
      my $title    = "";
      my $align    = "left";
      
      $ocol = {};

      if( $col eq "p" ) { $owner = 'label'    ; $info = 'partition';       $title="partition";                 }
      if( $col eq "P" ) { $owner = 'label'    ; $info = 'type';            $title="fs";                        }
      if( $col eq "l" ) { $owner = 'label'    ; $info = 'gptid';           $title="label";                     }
      if( $col eq "z" ) { $owner = 'label'    ; $info = 'zpool';           $title="zpool";                     }
      if( $col eq "Z" ) { $owner = 'label'    ; $info = 'zpool_location';  $title="zpool-location";            }
      if( $col eq "d" ) { $owner = 'device'   ; $info = 'device';          $title="device";                    }
      if( $col eq "t" ) { $owner = 'device'   ; $info = 'sectorsize';      $title="sector";    $align="right"; }
      if( $col eq "D" ) { $owner = 'device'   ; $info = 'description';     $title="disk";                      }
      if( $col eq "U" ) { $owner = 'device'   ; $info = 'disksize';        $title="size";      $align="right"; }
      if( $col eq "T" ) { $owner = 'device'   ; $info = 'type';            $title="type";                      }
      if( $col eq "S" ) { $owner = 'device'   ; $info = 'serial';          $title="serial";                    }
      if( $col eq "R" ) { $owner = 'device'   ; $info = 'rpm';             $title="rpm";       $align="right"; }
      if( $col eq "H" ) { $owner = 'smartctl' ; $info = 'temperature';     $title="temp";      $align="right"; }
      if( $col eq "e" ) { $owner = 'serial'   ; $info = 'url';             $title="sas-location";              }
      if( $col eq "m" ) { $owner = 'device'   ; $info = 'multipath';       $title="multipath";                 }
      if( $col eq "o" ) { $owner = 'device'   ; $info = 'multipath_mode';  $title="path-mode";                 }
      if( $col eq "s" ) { $owner = 'device'   ; $info = 'multipath_state'; $title="path-state";                }

      $ocol->{'owner'}     = $owner;
      $ocol->{'info'}      = $info;
      $ocol->{'title'}     = $title;
      $ocol->{'maxlength'} = length($title);       # computed later with values
      $ocol->{'align'}     = $align;

      push @layout , $ocol;
   }
}

sub getPrintableValue {
   my ($idev,$ilabel,$layout) = @_;

   my $owner = $layout->{'owner'};
   my $info  = $layout->{'info'};

   my $value = "";
   if( $owner eq "device" ) {
      $value = $idev->{ $info };
   }
   if( $owner eq "smartctl" ) {
      if( $idev->{ 'temperature' } eq "" ) {
         parseSmartctlDevice( $idev->{'device'} );
      }
      $value = $idev->{ $info };
   }
   if( $owner eq "label" ) {
       if( $ilabel eq "" ) {
           $value = "";
       }
       else {
           $value = $ilabel->{ $info };
       }
   } 
   if( $owner eq "serial" ) {
      if( exists( $sasdevices{ $idev->{'serial'} } ) ) {
           $value = $sasdevices{ $idev->{'serial'} }->{ $info };
      }
      else {
           $value = "";
      }
   }
   if( $info eq "disksize" ) {
      $value = floor( $value / 1000 / 1000 / 1000 );
   }
   if( $info eq "device" ) {
      if( $ilabel ne "" ) {
          $value = $ilabel->{'devices'};
      }
   }
   if( $info eq "multipath_mode" ) {
      if( $ilabel ne "" && $ilabel->{'devices'} =~ m/,/ ) {
          $value = "";
      }
   }

   if( !defined $value ) {
     print "Error while accessing data for (owner=$owner, data=$info)\n";
     die;
   }
   if( !defined $layout->{ 'maxlength' } ) {
     print "Error while accessing data for (owner=$owner, data=$info)\n";
     die;
   }
   if( length($value) > $layout->{ 'maxlength' } ) {
     $layout->{ 'maxlength' } = length($value);
   }
 
   return $value;
}

sub printReportHeader {
   if( $output_layout eq "list" ) {
      # do nothing
   }
   else {
      my $index = 0;
      foreach my $info ( @layout ) { 
          my $value = $info->{'title'};
          printComponent( $value , $info , $index );
          $index = $index + 1;
      }
      print "\n";

  
      if( $output_layout eq "col" ) { 
         my $line  = "";
            $index = 0;
         foreach my $info ( @layout ) { 
            
             my $field = ( '-' x $info->{'maxlength'} );
             if( $index > 0 ) {
                $line = $line . "--" . $field;
             }
             else {
                $line = $line . $field;
             }
             $index = $index + 1;
         }
         print $line . "\n";
      }
   }
}

sub printComponentHeader {
   my ($first) = @_;
   if( $output_layout eq "list" ) {
      if( $first == 0 ) { 
         print "\n";
         print "---------------------\n";
         print "\n";
      }
   }
   else {
      # do nothing
   }
}

sub printComponent {
   my ($value,$layout,$index) = @_;
   
   my $fmt    = "%s";
   my $sep    = ";";
   my $prefix = "";
   my $suffix = "";

   if( $output_layout eq "col" ) {
      if( $layout->{'align'} eq "right" ) {
         $fmt = "%+" . $layout->{'maxlength'} . "s";
      }
      else {
         $fmt = "%-" . $layout->{'maxlength'} . "s";
      }
      $sep = "  ";
   }
   if( $output_layout eq "list" ) {
      $sep    = "";
      $prefix = $layout->{'title'} . ": ";
      $suffix = "\n";
   }

   if( $index > 0 ) {
      print $sep;
   }
   print $prefix;
   printf( $fmt , $value );
   print $suffix;
}

sub printComponentFooter {
   if( $output_layout eq "list" ) {
      # do nothing
   }
   else {
      print "\n";
   }
}

sub printReportFooter {
   # do nothing
}

sub doReport {
   my ($print) = @_;

   # loop each components
   #
   if ( $print > 0 ) {
      printReportHeader;
   }
   
   my $first = 1;
   foreach my $label ( @partitionsKeys ) { 
      my $idev   = $devices{ $partitions{ $label }->{ 'device' } };
      my $ilabel = $partitions{ $label };
      my $value  = "";
      
      # filters
      if( applyFilterDevice($idev)  == 0 ) { next; }
      if( applyFilterLabel($ilabel) == 0 ) { next; }
  
      my $index = 0;
      if( $print > 0 ) {
         printComponentHeader($first);
         $first = 0;
      }
      foreach my $info ( @layout ) { 
          $value = getPrintableValue( $idev , $ilabel , $info );
          if( $print > 0 ) {
              printComponent( $value , $info , $index );
              $index = $index + 1;
          }
      }
      if( $print > 0 ) {
         printComponentFooter;
      }
   }
   foreach my $dev ( @devicesKeys ) {
      my $idev   = $devices{ $dev };
      my $ilabel = "";

      if( $idev->{ 'partitioned' } == 1 ) {
         next;
      }

      # filters
      if( applyFilterDevice($idev)  == 0 ) { next; }
      if( applyFilterLabel($ilabel) == 0 ) { next; }

      my $index = 0;

      if( $print > 0 ) { 
         printComponentHeader($first);
         $first = 0;
      }
      foreach my $info ( @layout ) { 
          my $value = getPrintableValue( $idev , $ilabel , $info );
          if( $print > 0 ) {
              printComponent( $value , $info , $index );
              $index = $index + 1;
          }
      }
      if( $print > 0 ) {
         printComponentFooter;
      }
   }
   if( $print > 0 ) { 
      printReportFooter;
   }
}

sub scan {
   # get host configuration
   #
   parseDisks();
   parsePartitions();
   parseMultiPath();
   parseZpools();
   parseSasDevices("sas2ircu");
   parseSasDevices("sas3ircu");
   completeDiskType();

   #printPartitions();

   # sort devices/partitions before filtering them
   #
   @partitionsKeys  = sort( { compare_labels($a,$b)  } keys %partitions );
   @devicesKeys     = sort( { compare_devices($a,$b) } keys %devices    );
}

sub report {
   my ($display_columns) = @_;

   # compute the layout (except padding)
   #
   prepareOutputLayout($display_columns);

   doReport(0); # just compute padding
   doReport(1); # real reporting
}

if( caller ) {
   parseArgumentsDiskList();
}
else {
   parseArgumentsDiskList(@ARGV);
   scan();
   report( $output_columns );
}

1;
