[!WARNING] 
Due to a deficiency of MariaDB in the replication option that makes it easy to lose synchronization of the databases, we decided to use DRBD, for which we recommend the following method instead of this one.
https://github.com/VitalPBX/vitalpbx4_drbd_ha

VitalPBX High Availability (Version 4)
=====
High availability is a characteristic of a system which aims to ensure an agreed level of operational performance, usually uptime, for a higher than normal period.<br>

Make a high-availability cluster out of any pair of VitalPBX servers. VitalPBX can detect a range of failures on one VitalPBX server and automatically transfer control to the other server, resulting in a telephony environment with minimal down time.<br>

### :warning:<strong>Important notes:</strong></span><br>
- If you are going to restore some Backup from another server that is not in HA, restore it first in the Master server before creating the HA. This should be done as the backup does not contain the firewall rules for HA to work.<br>
- The VitalPBX team does not provide support for systems in an HA environment because it is not possible to determine the environment where it has been installed.
- We recommend that Server 2 is completely clean if nothing is installed, otherwise the Script could give errors and the process would not be completed.

## Example:<br>
![VitalPBX HA](https://github.com/VitalPBX/vitalpbx_ha_v4/blob/main/HAReplica2Servers.png)

-----------------
## Prerequisites
In order to install VitalPBX in high availability you need the following:<br>
a.- 3 IP addresses.<br>
b.- Install VitalPBX Version 4.0 in two servers with similar characteristics.<br>
c.- MariaDB Galera (include in VitalPBX 4).<br>
d.- Corosync, Pacemaker, PCS and lsyncd.<br>
e.- Root user is required for both servers to communicate.<br>
f.- Both servers will not be able to have a proxy since this affects the communication between them.

## Configurations
We will configure in each server the hosname and IP address. 

| Name          | Master                 | Standby               |
| ------------- | ---------------------- | --------------------- |
| Hostname      | vitalpbx1.local        | vitalpbx2.local       |
| IP Address    | 192.168.10.61          | 192.168.10.62         |
| Netmask       | 255.255.255.0          | 255.255.255.0         |
| Gateway       | 192.168.10.1           | 192.168.10.1          |
| Primary DNS   | 8.8.8.8                | 8.8.8.8               |
| Secondary DNS | 8.8.4.4                | 8.8.4.4               |

### Server 1
Change Hostname
<pre>
root@vitalpbx1:~# hostname vitalpbx1.local
</pre>

Change Ip Address, edit the following file with nano, /etc/network/interfaces
<pre>
root@vitalpbx1:~# nano /etc/network/interfaces

Change
#The primary network interface
allow-hotplug eth0
iface eth0 inet dchp

With the following
#The primary network interface
allow-hotplug eth0
iface eth0 inet static
address 192.168.10.61
netmask 255.255.255.0
gateway 192.168.10.1
</pre>

### Server 2
Change Hostname
<pre>
root@vitalpbx2:~# hostname vitalpbx2.local
</pre>

Change Ip Address, edit the following file with nano, /etc/network/interfaces
<pre>
root@vitalpbx2:~# nano /etc/network/interfaces

Change
#The primary network interface
allow-hotplug eth0
iface eth0 inet dchp

With the following
#The primary network interface
allow-hotplug eth0
iface eth0 inet static
address 192.168.10.62
netmask 255.255.255.0
gateway 192.168.10.1
</pre>

Configure the hostname of each server in the /etc/hosts file, so that both servers see each other with the hostname.
<pre>
root@vitalpbx1-2:~# nano /etc/hosts
192.168.10.61 vitalpbx1.local master1
192.168.10.62 vitalpbx2.local master2
</pre>

## Bind Address
In the Master server go to SETTINGS/PJSIP Settings and configure the Floating IP that we are going to use in "Bind" and "TLS Bind".
Also do it in SETTINGS/SIP Settings Tab NETWORK fields "TCP Bind Address" and "TLS Bind Address".

## Install Dependencies
Install the necessary dependencies on both servers<br>
<pre>
root@vitalpbx1:~# apt -y install corosync pacemaker pcs lsyncd chrony
root@vitalpbx2:~# apt -y install corosync pacemaker pcs lsyncd chrony
</pre>

## Create authorization key for the Access between the two servers without credentials

Create key in Server <strong>1</strong>
<pre>
root@vitalpbx<strong>1</strong>:~# ssh-keygen -f /root/.ssh/id_rsa -t rsa -N '' >/dev/null
root@vitalpbx<strong>1</strong>:~# ssh-copy-id root@<strong>192.168.10.62</strong>
Are you sure you want to continue connecting (yes/no/[fingerprint])? <strong>yes</strong>
root@192.168.10.62's password: <strong>(remote server root’s password)</strong>

Number of key(s) added: 1

Now try logging into the machine, with:   "ssh 'root@192.168.10.62'"
and check to make sure that only the key(s) you wanted were added. 

root@vitalpbx<strong>1</strong>:~#
</pre>

Create key in Server <strong>2</strong>
<pre>
root@vitalpbx<strong>2</strong>:~# ssh-keygen -f /root/.ssh/id_rsa -t rsa -N '' >/dev/null
root@vitalpbx<strong>2</strong>:~# ssh-copy-id root@<strong>192.168.10.61</strong>
Are you sure you want to continue connecting (yes/no/[fingerprint])? <strong>yes</strong>
root@192.168.10.61's password: <strong>(remote server root’s password)</strong>

Number of key(s) added: 1

Now try logging into the machine, with:   "ssh 'root@192.168.10.61'"
and check to make sure that only the key(s) you wanted were added. 

root@vitalpbx<strong>2</strong>:~#
</pre>

## Script
Now copy and run the following script<br>
<pre>
root@vitalpbx<strong>1</strong>:~# mkdir /usr/share/vitalpbx/ha
root@vitalpbx<strong>1</strong>:~# cd /usr/share/vitalpbx/ha
root@vitalpbx<strong>1</strong>:~# wget https://raw.githubusercontent.com/VitalPBX/vitalpbx_ha_v4/master/vpbxha.sh
root@vitalpbx<strong>1</strong>:~# chmod +x vpbxha.sh
root@vitalpbx<strong>1</strong>:~# ./vpbxha.sh

************************************************************
*  Welcome to the VitalPBX high availability installation  *
*                All options are mandatory                 *
************************************************************
IP Server1............... > <strong>192.168.10.61</strong>
IP Server2............... > <strong>192.168.10.62</strong>
Floating IP.............. > <strong>192.168.10.60</strong>
Floating IP Mask (SIDR).. > <strong>24</strong>
hacluster password....... > <strong>MyPassword (any password)</strong>
************************************************************
*                   Check Information                      *
*        Make sure you have internet on both servers       *
************************************************************
Are you sure to continue with this settings? (yes,no) > <strong>yes</strong>
</pre>

At the end of the installation you have to see the following message

<pre>
************************************************************
*                VitalPBX Cluster OK                       *
*    Don't worry if you still see the status in Stop       *
*  sometimes you have to wait about 30 seconds for it to   *
*                 restart completely                       *
*         after 30 seconds run the command: role           *
************************************************************

 _    _ _           _ ______ ______ _    _
| |  | (_)_        | (_____ (____  \ \  / /
| |  | |_| |_  ____| |_____) )___)  ) \/ /
 \ \/ /| |  _)/ _  | |  ____/  __  ( )  (
  \  / | | |_( ( | | | |    | |__)  ) /\ \
   \/  |_|\___)_||_|_|_|    |______/_/  \_\


 Role           : Master
 Version        : 4.0.0-4
 Asterisk       : Asterisk 18.14.0
 Linux Version  : Debian GNU/Linux 11 (bullseye)
 Welcome to     : vitalpbx1.local
 Uptime         : 50 min
 Load           : Last Minute: 0.45, Last 5 Minutes: 0.40, Last 15 Minutes 0.19
 Users          : 4 users
 IP Address     : 192.168.10.61 192.168.10.60
 Clock          : Tue 2022-10-11 12:37:21 EDT
 NTP Sync.      : active


************************************************************
*                  Servers Status                          *
************************************************************
Master
  * virtual_ip  (ocf::heartbeat:IPaddr2):        Started vitalpbx1.local
  * asterisk    (service:asterisk):      Started vitalpbx1.local
  * lsyncd      (service:lsyncd.service):        Started vitalpbx1.local

Servers Status
  vitalpbx1.local: Online
  vitalpbx2.local: Online
</pre>

## Change Servers Role

To execute the process of changing the role, we recommend using the following command:<br>

<pre>
[root@vitalpbx-master /]# bascul
************************************************************
*     Change the roles of servers in high availability     *
* <strong>WARNING-WARNING-WARNING-WARNING-WARNING-WARNING-WARNING</strong>  *
*All calls in progress will be lost and the system will be *
*     be in an unavailable state for a few seconds.        *
************************************************************
Are you sure to switch from vitalpbx<strong>1</strong>.local to vitalpbx<strong>2</strong>.local? (yes,no) >
</pre>

This action convert the vitalpbx<strong>1</strong>.local to Standby and vitalpbx<strong>2</strong>.local to Master. If you want to return to default do the same again.<br>

Next we will show a short video how high availability works in VitalPBX<br>
<div align="center">
  <a href="https://www.youtube.com/watch?v=3yoa3KXKMy0"><img src="https://img.youtube.com/vi/3yoa3KXKMy0/0.jpg" alt="High Availability demo video on VitalPBX"></a>
</div>

## Recommendations
If you have to turn off both servers at the same time, we recommend that you start by turning off the one in Standby and then the Master<br>
If the two servers stopped abruptly, always start first that you think you have the most up-to-date information and a few minutes later the other server<br>
If you want to update the version of VitalPBX we recommend you do it first on Server 1, then do a bascul and do it again on Server 2<br>

## Update VitalPBX version

To update VitalPBX to the latest version just follow the following steps:<br>
1.- From your browser, go to ip 192.168.10.60<br>
2.- Update VitalPBX from the interface<br>
3.- Execute the following command in Master console<br>
<pre>
[root@vitalpbx1 /]# bascul
</pre>
4.- From your browser, go to ip 192.168.10.60 again<br>
5.- Update VitalPBX from the interface<br>
6.- Execute the following command in Master console<br>
<pre>
[root@vitalpbx1 /]# bascul
</pre>

## Some useful commands
• <strong>bascul</strong>, is used to change roles between high availability servers. If all is well, a confirmation question should appear if we wish to execute the action.<br>
• <strong>role</strong>, shows the status of the current server. If all is well you should return Masters or Slaves.<br>
• <strong>mariadbfix</strong>, on some occasions the synchronization between the databases is lost, the causes can be many, with this command this synchronization is recovered easily and quickly.<br>
• <strong>pcs resource refresh --full</strong>, to poll all resources even if the status is unknown, enter the following command.<br>
• <strong>pcs cluster unstandby host</strong>, in some cases the bascul command does not finish tilting, which causes one of the servers to be in standby (stop), with this command the state is restored to normal.<br>

## More Information
If you want more information that will help you solve problems about High Availability in VitalPBX we invite you to see the following manual<br>
[High Availability Manual, step by step](https://downloads.vitalpbx.com/vitalpbx/manuals/VitalPBXHighAvailabilityV4.pdf)

<strong>CONGRATULATIONS</strong>, you have installed and tested the high availability in <strong>VitalPBX 4</strong><br>
:+1:
