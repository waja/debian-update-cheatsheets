Please also refer to http://www.debian.org/releases/wheezy/releasenotes and use your brain!
For Roundcube and Sqlite Backend see: http://wiki.debian.org/Roundcube/DeprecationOfSQLitev2


# upgrade to UTF-8 locales (http://www.debian.org/releases/testing/i386/release-notes/ap-old-stuff.en.html#switch-utf8)
dpkg-reconfigure locales

# remove unused config file
rm -rf /etc/network/options /etc/environment
 
# change distro (please move 3rd party sources to /etc/apt/sources.list.d/), maybe look into http://ftp.cyconet.org/debian/sources.list.d/
sed -i s/squeeze/wheezy/g /etc/apt/sources.list*
sed -i "s/ stable/ wheezy/g" /etc/apt/sources.list*
sed -i s/squeeze/wheezy/g /etc/apt/preferences*
sed -i /proposed-updates/d /etc/apt/sources.list*
sed -i /volatile/d /etc/apt/sources.list*
sed -i /etch/d /etc/apt/sources.list*
sed -i /lenny/d /etc/apt/sources.list*
sed -i s#/backports.org/debian#/ftp.de.debian.org/debian#g /etc/apt/sources.list*
sed -i s/debian-backports/debian/g /etc/apt/sources.list*
if [ "$( dpkg -l | grep "^ii.*php5-suhosin" | wc -l)" -ge "1" ]; then \
  wget http://ftp.cyconet.org/debian/sources.list.d/wheezy-updates-cyconet.list \
  -O /etc/apt/sources.list.d/wheezy-updates-cyconet.list
fi
cat >> /etc/apt/preferences <<EOF
Package: *
Pin: release a=squeeze-lts
Pin-Priority: 200

EOF
aptitude update

# check package status
dpkg --audit
aptitude search "~ahold" | grep "^.h"
dpkg --get-selections | grep hold
 
# unmark packages auto
aptitude unmarkauto vim shorewall
aptitude unmarkauto $(dpkg-query -W 'linux-image-2.6.*' | cut -f1)
 
# have a look into required and free disk space
apt-get -o APT::Get::Trivial-Only=true dist-upgrade || df -h

# check if we have PAE available (http://www.debian.org/releases/testing/i386/release-notes/ch-upgrading.en.html#idp573136)
grep -q '^flags.*\bpae\b' /proc/cpuinfo && echo "We support PAE: yes" \
|| echo "We support PAE: no (please install linux-image-486 and remove linux-image-.*-686)"

# record session
script -t 2>~/upgrade-wheezy.time -a ~/upgrade-wheezy.script

# install our preseed so libc doesn't whine
cat > /tmp/wheezy.preseed <<EOF
libc6 glibc/upgrade boolean true
libc6 glibc/restart-services string
libc6 libraries/restart-without-asking boolean true
EOF
/usr/bin/debconf-set-selections /tmp/wheezy.preseed

# minimal system upgrade
aptitude upgrade

# randomize crontab
if [ -f /etc/crontab.dpkg-new ]; then CFG=/etc/crontab.dpkg-new; else CFG=/etc/crontab; fi
sed -i 's#root    cd#root    perl -e "sleep int(rand(300))" \&\& cd#' $CFG
sed -i 's#root\ttest#root\tperl -e "sleep int(rand(3600))" \&\& test#' $CFG

# phpmyadmin
if [ -f /etc/phpmyadmin/config.inc.php.dpkg-new ]; then CFG=/etc/phpmyadmin/config.inc.php.dpkg-new; \
   else CFG=/etc/phpmyadmin/config.inc.php; fi
sed -i "s/\['auth_type'\] = 'cookie'/\['auth_type'\] = 'http'/" $CFG
sed -i "s#//\$cfg\['Servers'\]\[\$i\]\['auth_type'\] = 'http';#\$cfg['Servers'][\$i]['auth_type'] = 'http';#" $CFG

# remove anonymous mysql access
mysql -u root -p -e "DELETE FROM mysql.user WHERE User=''; DELETE FROM mysql.db WHERE Db='test' AND Host='%' OR Db='test\\_%' AND Host='%'; FLUSH PRIVILEGES;"

if [ -f /etc/default/xendomains.dpkg-new ]; then CFG=/etc/default/xendomains.dpkg-new; \
   else CFG=/etc/default/xendomains; fi
sed -i s/XENDOMAINS_RESTORE=true/XENDOMAINS_RESTORE=false/ $CFG
sed -i s#XENDOMAINS_SAVE=/var/lib/xen/save#XENDOMAINS_SAVE=\"\"# $CFG

# dont use iptables when creating xen vifs
if [ -f /etc/xen/xend-config.sxp.dpkg-new ]; then CFG=/etc/xen/xend-config.sxp.dpkg-new; \
   else CFG=/etc/xen/xend-config.sxp; fi
sed -i "s/^(vif-script vif-bridge)/(vif-script vif-bridge-local)/" $CFG
/bin/sed -i -e 's/^[# ]*\((dom0-min-mem\).*\().*\)$/\1 512\2/' $CFG

cp /etc/xen/scripts/vif-bridge /etc/xen/scripts/vif-bridge-local
sed -i "s/^    handle_iptable/    true/g" /etc/xen/scripts/vif-bridge-local

# chrony update
if [ -f /etc/chrony/chrony.conf.new ]; then CFG=/etc/chrony/chrony.conf.new; else CFG=/etc/chrony/chrony.conf; fi
sed -i s/debian.pool/de.pool/g $CFG

rm -rf /etc/grub.d/09_linux_xen
dpkg-divert --divert /etc/grub.d/09_linux_xen --rename /etc/grub.d/20_linux_xen
#mv /etc/grub.d/20_linux_xen /etc/grub.d/09_linux_xen
echo 'GRUB_CMDLINE_XEN="dom0_mem=512M"' >> /etc/default/grub

# maybe we want to change some shorewall config stuff again
if [ -f /etc/default/shorewall.dpkg-new ]; then CFG=/etc/default/shorewall.dpkg-new; \
   else CFG=/etc/default/shorewall; fi
sed -i s/^startup=0/startup=1/ $CFG

# dist-upgrade
aptitude dist-upgrade

# migrate expose.ini
[ -f /etc/php5/conf.d/expose.ini ] && mv /etc/php5/conf.d/expose.ini \
 /etc/php5/mods-available/local-expose.ini && php5enmod local-expose/90
# migrate local suhosin config
find /etc/php5/conf.d/ -type f -name "*suhosin.ini" -exec mv '{}' \
 /etc/php5/mods-available/local-suhosin.ini \; && php5enmod local-suhosin/90

# mysql

# vsftpd and chroot_local_user?
if [ "$(grep -i  ^chroot_local_user=yes /etc/vsftpd.conf | wc -l)" -ge "1" ]; then \
  aptitude update; aptitude install -t wheezy-updates vsftpd && \
  echo "allow_writeable_chroot=YES" >> /etc/vsftpd.conf && /etc/init.d/vsftpd restart; \
fi

# install fixed quotatool
dpkg -l | grep quotatool && aptitude update; aptitude safe-upgrade -t wheezy-updates quotatool

# remove old squeeze packages left around (keep eyes open!)
apt-get autoremove
aptitude search ?obsolete
dpkg -l | grep etch | grep -v xen | grep -v unbound | grep -v finch | awk '{print $2}' | xargs aptitude -y purge
dpkg -l | grep lenny | grep -v xen | awk '{print $2}' | xargs aptitude -y purge
dpkg -l | grep squeeze | grep -v xen | grep -v linux-image | awk '{print $2}' | xargs aptitude -y purge
aptitude -y install deborphan && deborphan | grep -v xen | grep -v libpam-cracklib | xargs aptitude -y purge
dpkg -l | grep ^r | awk '{print $2}' | xargs aptitude -y purge

# for the brave YoloOps crowd
reboot && sleep 180; echo u > /proc/sysrq-trigger ; sleep 2 ; echo s > /proc/sysrq-trigger ; sleep 2 ; echo b > /proc/sysrq-trigger
