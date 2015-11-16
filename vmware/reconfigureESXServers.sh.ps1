#!/bin/bash
# Set variables
myoldhostfqdn=`hostname`
myoldhostshort=`hostname -s`
myoldhostIP=`/usr/sbin/esxcfg-vswif -l | grep vswif0 | awk '{print $4}'`
myoldVMotionIP=`esxcfg-vmknic -l | grep VMotion | awk '{print $3}'`
myServiceConsoleName="Service Console"
myoldIPInteger=`esxcfg-vswif -l  | grep "$myServiceConsoleName" | awk '{print $4}' | sed 's/\./ /g' | awk '{print $4}'`
myoldNameInteger=`hostname -s | sed 's/bneesx//g'`
myoldVMotionPortGroup=`esxcfg-vswitch -l | grep 'VMotion_103' | awk '{print $1}'`
myoldVMotionIP=`esxcfg-vmknic -l | grep 'VMotion_103' | awk '{print $3}'`
myoldVMotionMask=`esxcfg-vmknic -l | grep 'VMotion_103' | awk '{print $4}'`
myoldVMotionDevice=`esxcfg-vmknic -l| grep 'VMotion_103' | awk '{print $1}'`


mynewIPInteger=`expr $myoldIPInteger - 22`
#mynewIPInteger="29"
mynewhostshort="aubne-s-msesx$myoldNameInteger"
mynewdomainname="gms.mincom.com"
mynewhostfqdn="$mynewhostshort.$mynewdomainname";
mynewhostIP="10.161.27.$mynewIPInteger";
newServiceConsoleVLANID="527"
mynewVmotionIP="10.161.28.$mynewIPInteger";
mynewvmotionVLANID="528";
mymask="255.255.255.0";
mynewgatewayIP="10.161.27.254";
myntp=$mynewgatewayIP;
mgmtvSwitch="vSwitch0";
newVMotionPGName="VMotion";
newVMotionDefaultGW="10.161.28.254"

# backup files and configurations
backuplocation="/root/admin/backups"
mkdir -p $backuplocation
cp /etc/sysconfig/network $backuplocation/network.April2014
cp /etc/hosts $backuplocation/hosts.April2014
cp /etc/resolv.conf $backuplocation/resolv.conf.April2014
esxcfg-vswitch -l > $backuplocation/vswitch-details.April2014
esxcfg-vswif -l > $backuplocation/vswif-details.April2014


service network stop
service mgmt-vmware stop
service vmware-vpxa stop


# Service Console interface
esxcfg-vswitch -D "$myServiceConsoleName" $mgmtvSwitch
esxcfg-vswitch -A "$myServiceConsoleName" $mgmtvSwitch
esxcfg-vswitch -p "$myServiceConsoleName" -v $newServiceConsoleVLANID $mgmtvSwitch
esxcfg-vswif --disable vswif0
esxcfg-vswif --del vswif0
esxcfg-vswif --add --portgroup "$myServiceConsoleName" --ip=$mynewhostIP --netmask=$mymask vswif0

# VMotion interface
esxcfg-vmknic --del $myoldVMotionPortGroup
esxcfg-vswitch -D $myoldVMotionPortGroup $mgmtvSwitch
esxcfg-vswitch -A $newVMotionPGName $mgmtvSwitch
esxcfg-vmknic --add --ip=$mynewVmotionIP --netmask=$mymask $newVMotionPGName
esxcfg-vswitch -p $newVMotionPGName -v $mynewvmotionVLANID $mgmtvSwitch
esxcfg-vmknic --enable $newVMotionPGName
esxcfg-route $newVMotionDefaultGW

cat > /etc/sysconfig/network << EOF
NETWORKING=yes
GATEWAYDEV=vswif0
HOSTNAME=$mynewhostfqdn
GATEWAY=$mynewgatewayIP
EOF

cat >> /etc/hosts << EOF
$mynewhostIP    $mynewhostfqdn $mynewhostshort
$mynewVmotionIP    $mynewhostshort-vmotion.$mynewdomainname $mynewhostshort-vmotion
10.161.26.1     aubne-s-msvcenter.gms.mincom.com aubne-s-msvcenter mmsbnevcm01 mmsbnevcm01.gms.mincom.com
EOF

cat > /etc/resolv.conf << EOF
search gms.mincom.com
nameserver 10.161.30.20
nameserver 10.161.30.21
EOF

hostname $mynewhostfqdn
service network start
service vmware-vpxa restart
service mgmt-vmware start

echo "Don't forget to set VMotion primary nic as VMNIC4 and failover onto VMNIC0"