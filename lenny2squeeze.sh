Please also refer to http://www.debian.org/releases/lenny/releasenotes and use your brain! If you can’t figure out what one of the commands below does, this is not for you. Expert mode only :)

# http://www.debian.org/releases/squeeze/i386/release-notes/ch-upgrading.de.html#purge-splashy
aptitude purge splashy

# change distro
sed -i s/lenny-restricted/restricted/g /etc/apt/sources.list
sed -i s/lenny/squeeze/g /etc/apt/sources.list
sed -i "s/ stable/ squeeze/g" /etc/apt/sources.list
sed -i s/lenny/squeeze/g /etc/apt/preferences
sed -i /proposed-updates/d /etc/apt/sources.list
sed -i /volatile/d /etc/apt/sources.list
sed -i /etch/d /etc/apt/sources.list
sed -i s#/backports.org/debian#/ftp.de.debian.org/debian-backports#g /etc/apt/sources.list
echo -e "\n#" >> /etc/apt/sources.list && \
echo "# squeeze-updates" >> /etc/apt/sources.list && \
echo "#" >> /etc/apt/sources.list && \
echo -e "deb\thttp://debian.tmt.de/debian\tsqueeze-updates\tmain" >> \
/etc/apt/sources.list
aptitude update

# check package status
dpkg --audit
aptitude search "~ahold" | grep "^.h"
dpkg --get-selections | grep hold

# unmark packages auto
aptitude unmarkauto vim
aptitude unmarkauto $(dpkg-query -W 'linux-image-2.6.*' | cut -f1)

# have a look into required and free disk space
apt-get -o APT::Get::Trivial-Only=true dist-upgrade || df -h

# record session
script -t 2>~/upgrade-squeeze.time -a ~/upgrade-squeeze.script

# update aptitude first
#aptitude install aptitude

# converting auto packages from aptitude to apt with any aptitude command
#aptitude search "?false"

# minimal system upgrade
aptitude upgrade



# disable to bind mysql to localhost (from etch -> lenny migrtation)
# echo -e "[mysqld]\nbind-address           = 0.0.0.0" > /etc/mysql/conf.d/bind.cnf

# phpmyadmin
echo "create database phpmyadmin" | mysql -p
sed -i "s/\['auth_type'\] = 'cookie'/\['auth_type'\] = 'http'/" /etc/phpmyadmin/config.inc.php
sed -i "s#//\$cfg\['Servers'\]\[\$i\]\['auth_type'\] = 'http';#\$cfg['Servers'][\$i]['auth_type'] = 'http';#" /etc/phpmyadmin/config.inc.php

 

# reintroduce community

sed -i "s^#rocommunity secret  10.0.0.0/16^rocommunity public^g" /etc/snmp/snmpd.conf
sed -i s/#agentAddress/agentAddress/ /etc/snmp/snmpd.conf
sed -i "s/agentAddress  udp:127/#agentAddress  udp:127/" /etc/snmp/snmpd.conf



# exchange debian ntp server with german once
sed -i "s/debian\.pool\.ntp\.org/de.pool.ntp.org/g" /etc/ntp.conf

# fix pam
sed -i "s/# auth       required   pam_wheel.so/auth       required   pam_wheel.so/" /etc/pam.d/su

# maybe we want to change some shorewall config stuff again
sed -i s/DISABLE_IPV6=Yes/DISABLE_IPV6=No/ /etc/shorewall/shorewall.conf
sed -i s/^startup=0/startup=1/ /etc/default/shorewall



# reenable mailnotification of smartmond
sed -i "s/m root -M exec/I 194 -I 231 -I 9 -m foo@bar.org -M exec/" /etc/smartd.conf
# for 3ware you may instead need
echo "/dev/twa0 -d 3ware,0 -a -s (L/../../7/02|S/../.././02) -I 194 -I 231 -I 9 -m foo@bar.org -M exec /usr/share/smartmontools/smartd-runner" >> /etc/smartd.conf
echo "/dev/twa0 -d 3ware,1 -a -s (L/../../7/03|S/../.././03) -I 194 -I 231 -I 9 -m foo@bar.org -M exec /usr/share/smartmontools/smartd-runner" >> /etc/smartd.conf



# disable php expose
echo "expose_php = Off" > /etc/php5/apache2/conf.d/expose.ini

# fix proftpd

sed -i s/DisplayFirstChdir/DisplayChdir/g /etc/proftpd/proftpd.conf
sed -i s/SQLHomedirOnDemand/CreateHome/g /etc/proftpd/proftpd.conf
/etc/init.d/proftpd restart

# install kernel image
aptitude install linux-image-2.6-flavor
# install udev
aptitude install udev



# dist-upgrade
aptitude dist-upgrade



# install rsyslog in favor of sysklogd

aptitude install rsyslog


# remove old lenny packages left around (keep eyes open!)
aptitude search ?obsolete
dpkg -l | grep etch | grep -v xen | awk '{print $2}' | xargs aptitude -y purge
dpkg -l | grep lenny | grep -v xen | grep -v linux-image | awk '{print $2}' | xargs aptitude -y purge
aptitude -y install deborphan && deborphan | grep -v xen | grep -v libpam-cracklib | xargs aptitude -y purge
dpkg -l | grep ^r | awk '{print $2}' | xargs aptitude -y purge

# Maybe switch to dependency based boot system?
aptitude purge libdevmapper1.02
dpkg-reconfigure sysv-rc

# migrate xen console see http://wiki.dunharg.cyconet.org/Documentation/Sniplets/Migration_from_Lenny_to_Squeeze/Enable_%2f%2fdev%2f%2fhvc_in_domU
sed -i s/XENDOMAINS_RESTORE=true/XENDOMAINS_RESTORE=false/ /etc/default/xendomains
sed -i s#XENDOMAINS_SAVE=/var/lib/xen/save#XENDOMAINS_SAVE=\"\"# /etc/default/xendomains


# wenn webalizer installiert
dpkg -l | grep webalizer && aptitude install geoip-database

# Maybe fix Vhosts
sed -i "s#/var/log/apache2#\$\{APACHE_LOG_DIR\}#g" /etc/apache2/sites-available/default
sed -i 's/ErrorLog "|/ErrorLog "||/' /etc/apache2/sites-available/*

# remove ipv6 workaround
sed -i "/up.*modprobe.* ipv6/d" /etc/network/interfaces


# Upgrade to Grub2?
upgrade-from-grub-legacy
