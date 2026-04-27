# Centreon 2.6 installation on Amazon Linux 2023 and mysql 8.4
```
yum install spal-release yum-utils python3-dnf-plugin-post-transaction-actions -y
yum update -y

yum install chrony net-snmp nagios nagios-plugins-all mysql-community-devel rrdtool rrdtool-perl git gcc perl-Sys-Syslog php8.5-mysqlnd.x86_64 php8.5-intl php8.5-mbstring.x86_64 php8.5-gd php8.5-ldap perl-Net-SNMP perl-Config-IniFiles perl-DBD-MySQL -y

systemctl enable chrony
sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
reboot

CENTREON_HOME=/opt/centreon
mkdir -p $CENTREON_HOME
git checkout git@github.com:jazzl0ver/centreon26.git $CENTREON_HOME

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

ln -s $CENTREON_HOME/etc/dnf/plugins/post-transaction-actions.d/nagios_update_perms.action /etc/dnf/plugins/post-transaction-actions.d/
ln -s $CENTREON_HOME/usr/share/centreon /usr/share
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
ln -s $CENTREON_HOME/usr/share/centreon/www/lib/HTML $CENTREON_HOME/usr/share/centreon/www/include/configuration/configObject/command/
ln -s $CENTREON_HOME/usr/share/centreon/www/lib/HTML $CENTREON_HOME/usr/share/centreon/www/include/monitoring/external_cmd/popup

ln -s /usr/lib64/nagios /usr/lib

sed -i 's|;date.timezone.*|date.timezone = Etc/UTC|' /etc/php.ini

chown centreon: $CENTREON_HOME/usr/share/centreon/www/install/install.conf.php

/usr/sbin/usermod -a -G centreon,apache nagios
/usr/sbin/usermod -a -G centreon,nagios apache
/usr/sbin/usermod -a -G nagios centreon

chown -R nagios: /etc/nagios
chmod -R g+w /etc/nagios

# Fix right
chmod g+w -R /var/log/nagios
chmod g-w /usr/bin/nagiostats
chgrp nagios /usr/bin/nagiostats
mkdir /var/log/nagios/rw
chown nagios. /var/log/nagios/rw

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

cp $CENTREON_HOME/etc/sysctl.d/20-ndo2db.conf /etc/sysctl.d/
#-- required to fix 'sysctl: setting key "kernel.shmmni": Invalid argument' issue
grubby --update-kernel=ALL --args='ipcmni_extend'

systemctl enable ndo2db.service
systemctl enable nagios

# Prepare macro for SQL
/usr/share/centreon/install/prepare_sql_macros.sh

# Apply macros to sql files
/usr/bin/find /usr/share/centreon/www/install/ -type f | grep \.sql | xargs sed -i -f /usr/share/centreon/install/sql_macros.sed
/usr/bin/find /usr/share/centreon/www/install/ -type f | grep \.sql | xargs sed -i "s/@DB_PASS@/$dbpasswd/g"
sed -i "s/@CENTREON_DB_PASS@/$dbpasswd/g" /usr/share/centreon/install/centreon-create-databases.sql

/usr/bin/mysql -u root < /usr/share/centreon/install/centreon-create-databases.sql
/usr/bin/mysql -u root centreon < /usr/share/centreon/www/install/createTables.sql
/usr/bin/mysql -u root centreon_storage < /usr/share/centreon/www/install/createTablesCentstorage.sql
/usr/bin/mysql -u root centreon_storage < /usr/share/centreon/www/install/installBroker.sql
/usr/bin/mysql -u root centreon_status < /usr/share/centreon/www/install/createNDODB.sql

# Insert SQL
/usr/bin/mysql -u root centreon < /usr/share/centreon/www/install/insertMacros.sql
/usr/bin/mysql -u root centreon < /usr/share/centreon/www/install/insertCmd-Tps.sql
/usr/bin/mysql -u root centreon < /usr/share/centreon/www/install/var/baseconf/nagios.sql
/usr/bin/mysql -u root centreon < /usr/share/centreon/www/install/var/baseconf/ndoutils.sql

/usr/bin/mysql -u root centreon < /usr/share/centreon/www/install/insertTopology.sql
/usr/bin/mysql -u root centreon < /usr/share/centreon/www/install/insertBaseConf.sql
/usr/bin/mysql -u root centreon < /usr/share/centreon/www/install/insertACL.sql

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

systemctl enable --now centcore
systemctl enable --now centstorage
```