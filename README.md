# centreon26
Centreon version 2.6 (www.centreon.com) onto CentOS 7 installation instructions

```
yum install epel-release yum-utils -y
yum update -y
yum install ntp net-snmp nagios nagios-plugins-all mariadb-server mariadb-devel rrdtool rrdtool-perl git gcc perl-Sys-Syslog php-mysql php-pear-DB php-intl php-mbstring php-gd php-ldap perl-Net-SNMP perl-Config-IniFiles -y

systemctl enable ntpd ntpdate
sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
reboot

CENTREON_HOME=/opt/centreon
mkdir -p $CENTREON_HOME

cat <<EOT > /etc/yum.repos.d/ces-standard.repo
[ces-standard]
name=Centreon RPM repository for ces \$releasever
baseurl=http://yum.centreon.com/standard/3/stable/\$basearch/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CES

[ces-standard-noarch]
name=Centreon RPM repository for ces \$releasever
baseurl=http://yum.centreon.com/standard/3/stable/noarch/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CES

[ces-standard-deps]
name=Centreon dependencies RPM repository for ces \$releasever
baseurl=http://yum.centreon.com/standard/3/stable/dependencies/\$basearch/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CES

[ces-standard-deps-noarch]
name=Centreon dependencies RPM repository for ces \$releasever
baseurl=http://yum.centreon.com/standard/3/stable/dependencies/noarch/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CES
EOT

rpmkeys --import https://yum.centreon.com/standard/3.0/stable/RPM-GPG-KEY-CES
yum install php-pear-Archive-Zip -y

yumdownloader nagios-core-3.2.3-6.el6.x86_64 centreon-2.6.6-5.el6.noarch centreon-base-config-nagios-2.6.6-5.el6.noarch centreon-common-2.6.6-5.el6.noarch centreon-installed-2.6.6-5.el6.noarch centreon-perl-libs-2.6.6-5.el6.noarch centreon-plugin-meta-2.6.6-5.el6.noarch centreon-plugins-2.6.6-5.el6.noarch centreon-plugins-base-1.17-1.el6.noarch centreon-trap-2.6.6-5.el6.noarch centreon-web-2.6.6-5.el6.noarch \
	centreon-widget-graph-monitoring-1.2.0-2.el6.noarch centreon-widget-hostgroup-monitoring-1.2.1-1.el6.noarch centreon-widget-host-monitoring-1.3.2-1.el6.noarch centreon-widget-servicegroup-monitoring-1.2.1-1.el6.noarch centreon-widget-service-monitoring-1.3.2-1.el6.noarch
# for standalone poller: yumdownloader centreon-poller-nagios-2.6.6-5.el6.noarch

for i in $(ls -1 *.rpm | grep -v nagios-core); do rpm2cpio $i | (cd $CENTREON_HOME; cpio -div); done
rpm2cpio nagios-core-3.2.3-6.el6.x86_64.rpm | (cd $CENTREON_HOME; cpio -div ./usr/sbin/p1.pl)

/usr/bin/getent group centreon &>/dev/null || /usr/sbin/groupadd -r centreon
/usr/bin/getent passwd centreon &>/dev/null || /usr/sbin/useradd -g centreon -m -d $CENTREON_HOME/var/spool/centreon -r centreon 2> /dev/null

chown -R centreon:centreon $CENTREON_HOME/var/log/centreon
chown -R centreon:centreon $CENTREON_HOME/var/lib/centreon
chmod -R g+w $CENTREON_HOME/var/lib/centreon
chown -R centreon:centreon $CENTREON_HOME/usr/share/centreon/filesGeneration
chmod -R g+wrxs $CENTREON_HOME/usr/share/centreon/filesGeneration
chown -R centreon:centreon $CENTREON_HOME/usr/share/centreon/filesUpload
chmod -R g+wrxs $CENTREON_HOME/usr/share/centreon/filesUpload
chown -R centreon:centreon $CENTREON_HOME/usr/share/centreon/GPL_LIB/SmartyCache
chmod -R g+wrxs $CENTREON_HOME/usr/share/centreon/GPL_LIB/SmartyCache
chown -R centreon:centreon $CENTREON_HOME/var/run/centreon
chmod -R g+w $CENTREON_HOME/var/run/centreon

ln -s $CENTREON_HOME/usr/share/centreon /usr/share
mkdir /usr/share/centreon/backup
ln -s $CENTREON_HOME/var/lib/centreon /var/lib
ln -s $CENTREON_HOME/etc/centreon /etc/centreon
ln -s $CENTREON_HOME/etc/cron.d/* /etc/cron.d/
ln -s $CENTREON_HOME/etc/httpd/conf.d/* /etc/httpd/conf.d/
ln -s $CENTREON_HOME/etc/init.d/* /etc/init.d/
ln -s $CENTREON_HOME/etc/logrotate.d/* /etc/logrotate.d/
ln -s $CENTREON_HOME/etc/snmp/* /etc/snmp/
ln -s $CENTREON_HOME/etc/sudoers.d/* /etc/sudoers.d/
ln -s $CENTREON_HOME/etc/sysconfig/* /etc/sysconfig/
ln -s $CENTREON_HOME/usr/sbin/p1.pl /usr/sbin/
ln -s $CENTREON_HOME/usr/share/perl5/vendor_perl/* /usr/share/perl5/vendor_perl/
ln -s $CENTREON_HOME/usr/lib/nagios/plugins/* /usr/lib64/nagios/plugins/
ln -s $CENTREON_HOME/var/log/centreon /var/log/
ln -s $CENTREON_HOME/var/spool/centreon /var/spool/
ln -s /usr/lib64/nagios /usr/lib

cat <<EOT >> $CENTREON_HOME/etc/sudoers.d/*
CENTREON   ALL = NOPASSWD: /sbin/service nagios restart
CENTREON   ALL = NOPASSWD: /sbin/service nagios start
CENTREON   ALL = NOPASSWD: /sbin/service nagios stop
CENTREON   ALL = NOPASSWD: /sbin/service nagios reload
CENTREON   ALL = NOPASSWD: /sbin/service ndo2db restart
CENTREON   ALL = NOPASSWD: /sbin/service ndo2db start
CENTREON   ALL = NOPASSWD: /sbin/service ndo2db stop
CENTREON   ALL = NOPASSWD: /sbin/service ndo2db reload
EOT

sed -i 's/Order allow,deny/Require all granted/' $CENTREON_HOME/etc/httpd/conf.d/*
sed -i 's/Allow from all//' $CENTREON_HOME/etc/httpd/conf.d/*
sed -i 's|;date.timezone.*|date.timezone = Etc/UTC|' /etc/php.ini
sed -i 's/size 20M/size 20M\nsu root root/' $CENTREON_HOME/etc/logrotate.d/*

sed -i "s|/usr/lib/|/usr/lib64/|g" /usr/share/centreon/www/install/install-web-nagios
sed -i 's|/etc/init.d/|/sbin/service |g' /usr/share/centreon/www/install/install-web-nagios
/bin/cp /usr/share/centreon/www/install/install-web-nagios /usr/share/centreon/www/install/install.conf.php
chown centreon: /usr/share/centreon/www/install/install.conf.php

/usr/sbin/usermod -a -G centreon,apache nagios
/usr/sbin/usermod -a -G centreon,nagios apache
/usr/sbin/usermod -a -G nagios centreon

chown -R nagios: /etc/nagios
chmod -R g+w /etc/nagios

# Fix right
chmod g+w -R /var/log/nagios
chmod +x /usr/bin/nagiostats
mkdir /var/log/nagios/rw
chown nagios. /var/log/nagios/rw

mv /etc/centreon/instCentPlugins.conf_nagios /etc/centreon/instCentPlugins.conf
mv /etc/centreon/instCentWeb.conf_nagios /etc/centreon/instCentWeb.conf

sed -i 's|/usr/lib/nagios/plugins|/usr/lib64/nagios/plugins|' /etc/centreon/*

/bin/cp /etc/my.cnf /usr/share/centreon/backup

# Optimize mysql
sed -i -f /usr/share/centreon/install/centreon-my.cnf-optim.sed /etc/my.cnf
systemctl enable --now mariadb

# Add right in SNMP
sed -i \
        -e "/^view.*\.1\.3\.6\.1\.2\.1\.1$/i\
view centreon included .1.3.6.1" \
        -e "/^access.*$/i\
access notConfigGroup \"\" any noauth exact centreon none none" \
        /etc/snmp/snmpd.conf

systemctl enable --now snmpd

systemctl enable --now httpd

# Generate a password
dbpasswd=`openssl rand -base64 42 | head -c 12 | sed -e 's@/@{@'`

git clone https://github.com/NagiosEnterprises/ndoutils.git
cd ndoutils/
./configure --prefix=$CENTREON_HOME --sysconfdir=$CENTREON_HOME/etc/ndo --localstatedir=$CENTREON_HOME/var/run/ndo && make all
cd db
echo "create database centreon_status;" | mysql
./installdb -u root -p "" -h localhost -d centreon_status
cd ..
make install
make install-config
ln -s /opt/centreon/bin/ndomod.o /usr/lib64/nagios/
ln -s /etc/nagios/ndo2db.cfg $CENTREON_HOME/etc/ndo/
ln -s /etc/nagios/ndomod.cfg $CENTREON_HOME/etc/ndo/
make install-init

cat <<EOT > /etc/sysctl.d/20-ndo2db.conf
kernel.msgmnb = 131072000
kernel.msgmax = 131072000
kernel.msgmni = 512000
EOT

systemctl enable ndo2db.service
systemctl enable nagios

# Prepare macro for SQL
sed -i 's/localhost/127.0.0.1/g' /usr/share/centreon/install/prepare_sql_macros.sh
sed -i 's|/etc/init.d/|/sbin/service |g' /usr/share/centreon/install/prepare_sql_macros.sh
/usr/share/centreon/install/prepare_sql_macros.sh

# Apply macros to sql files
/usr/bin/find /usr/share/centreon/www/install/ -type f | grep \.sql | xargs sed -i -f /usr/share/centreon/install/sql_macros.sed
/usr/bin/find /usr/share/centreon/www/install/ -type f | grep \.sql | xargs sed -i "s/@DB_PASS@/$dbpasswd/g"

# Create sql users and databases
sed -i "s/@CENTREON_DB_PASS@/$dbpasswd/g" /usr/share/centreon/install/centreon-create-databases.sql
sed -i "s/CREATE DATABASE/CREATE DATABASE IF NOT EXISTS/g" /usr/share/centreon/install/centreon-create-databases.sql

/usr/bin/mysql -u root < /usr/share/centreon/install/centreon-create-databases.sql
/usr/bin/mysql -u root centreon < /usr/share/centreon/www/install/createTables.sql
/usr/bin/mysql -u root centreon_storage < /usr/share/centreon/www/install/createTablesCentstorage.sql
/usr/bin/mysql -u root centreon_storage < /usr/share/centreon/www/install/installBroker.sql
/usr/bin/mysql -u root centreon_status < /usr/share/centreon/www/install/createNDODB.sql

# Insert SQL
/usr/bin/mysql -u root centreon < /usr/share/centreon/www/install/insertMacros.sql
/usr/bin/mysql -u root centreon < /usr/share/centreon/www/install/insertCmd-Tps.sql
sed -i 's|/usr/lib/nagios/plugins|/usr/lib64/nagios/plugins|' /usr/share/centreon/www/install/var/baseconf/nagios.sql
sed -i 's|/etc/init.d/|/sbin/service |g' /usr/share/centreon/www/install/var/baseconf/nagios.sql
/usr/bin/mysql -u root centreon < /usr/share/centreon/www/install/var/baseconf/nagios.sql
/usr/bin/mysql -u root centreon < /usr/share/centreon/www/install/var/baseconf/ndoutils.sql

/usr/bin/mysql -u root centreon < /usr/share/centreon/www/install/insertTopology.sql
sed -i 's|/usr/lib/nagios/plugins|/usr/lib64/nagios/plugins|' /usr/share/centreon/www/install/insertBaseConf.sql
sed -i 's|/etc/init.d/|/sbin/service |g' /usr/share/centreon/www/install/insertBaseConf.sql
/usr/bin/mysql -u root centreon < /usr/share/centreon/www/install/insertBaseConf.sql
/usr/bin/mysql -u root centreon < /usr/share/centreon/www/install/insertACL.sql

# Create configuration files
sed -i 's/localhost/127.0.0.1/g' /etc/centreon/*
sed -i "s/@CENTREON_DB_PASS@/$dbpasswd/g" /etc/centreon/centreon.conf.php
sed -i "s/@CENTREON_DB_PASS@/$dbpasswd/g" /etc/centreon/conf.pm

chown centreon: /etc/centreon/conf.pm
chmod g+w /etc/centreon/conf.pm

# Delete install directories
/bin/rm -rf /usr/share/centreon/install
/bin/rm -rf /usr/share/centreon/www/install

if [ -f /etc/snmp/snmptrapd.conf ]; then
   grep disableAuthorization /etc/snmp/snmptrapd.conf &>/dev/null && \
       sed -i -e "s/disableAuthorization .*/disableAuthorization yes/g" /etc/snmp/snmptrapd.conf
   grep disableAuthorization /etc/snmp/snmptrapd.conf &>/dev/null || \
       cat <<EOF >> /etc/snmp/snmptrapd.conf
disableAuthorization yes
EOF
fi

/sbin/chkconfig --add centcore
/sbin/chkconfig --level 345 centcore on
/sbin/chkconfig --add centstorage
/sbin/chkconfig --level 345 centstorage on
```

Now log into the centreon web interface (admin/centreon) at **Configuration > Monitoring Engines > Generate** and export monitoring engine configuration

```
reboot
```

Enable widgets at **Administration > Extensions > Setup page**
