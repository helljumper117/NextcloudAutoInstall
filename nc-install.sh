#!/bin/bash

#----------------------------------------------------------------
#NextCloud Script von Marcel Gasser und Tobias Moor, IFA HFI 3613
#GNU GPLv3 licensed
#----------------------------------------------------------------



#----------------------------------------------------------------
#Root Rechte überprüfen

if [ "$EUID" -ne 0 ]
  then echo "Führen Sie den Befehl sudo -s aus und starten Sie das Skript erneut." 
  exit
else
  echo "Das Skript wird mit Root-Rechten ausgeführt"
fi

sleep 5
#----------------------------------------------------------------
#LOG Datei erstellen

touch /var/log/nc-install-log.txt

Startzeit=$(date)
echo "Das Script wird gestartet um $Startzeit" > /var/log/nc-install-log.txt
echo "Das Script wird gestartet um $Startzeit"

sleep 5
#----------------------------------------------------------------
#Internetverbindung überprüfen

if ping -q -c 1 -W 1 8.8.8.8 >/dev/null; then
  echo "Internetverbindung vorhanden" >> /var/log/nc-install-log.txt
  echo "Internetverbindung vorhanden"
else
  echo "Keine Internetverbindung vorhanden" >> /var/log/nc-install-log.txt
  echo "Keine Internetverbindung vorhanden"
  exit
fi

sleep 5
#----------------------------------------------------------------
# Auf Updates prüfen

apt-get update && apt-get upgrade -y
echo "Updates wurden installiert" >> /var/log/nc-install-log.txt
echo "Updates wurden installiert"

sleep 5
#----------------------------------------------------------------
# Apache2 installieren und aktivieren

apt-get install apache2 -y
systemctl stop apache2.service
systemctl start apache2.service
systemctl enable apache2.service
echo "Der Apache Webservice wurde installiert" >> /var/log/nc-install-log.txt
echo "Der Apache Webservice wurde installiert"

sleep 5
#----------------------------------------------------------------
# MariaDB installieren und absichern

apt-get install mariadb-server mariadb-client -y
systemctl stop mariadb.service
systemctl start mariadb.service
systemctl enable mariadb.service
MariaDBPW=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)
mysql -e "UPDATE mysql.user SET Password = PASSWORD('$MariaDBPW') WHERE User = 'root'"
mysql -e "DELETE FROM mysql.user WHERE User=''"
mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1')"
mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%'"
mysql -e "FLUSH PRIVILEGES"
echo "Hier ist der Maria-DB Benutzername: root" >> /var/log/nc-install-log.txt
echo "Hier ist das Maria-DB Root Passwort: $MariaDBPW" >> /var/log/nc-install-log.txt
systemctl restart mariadb.service
echo "MariaDB wurde erfolgreich installiert und abgesichert" >> /var/log/nc-install-log.txt
echo "MariaDB wurde erfolgreich installiert und abgesichert"

sleep 5
#----------------------------------------------------------------
# PHP-Module installieren

apt -y install php php-cli php-common php-curl php-xml php-gd php-mbstring php-zip php-mysql
service apache2 restart
echo "Die PHP Module wurden installiert" >> /var/log/nc-install-log.txt
echo "Die PHP Module wurden installiert"

sleep 5
#----------------------------------------------------------------
# Datenbank erstellen

ncuserPW=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)
mysql -e "CREATE DATABASE nextcloud"
mysql -e "CREATE USER 'ncuser'@'localhost' IDENTIFIED BY '$ncuserPW'"
mysql -e "GRANT ALL ON nextcloud.* TO 'ncuser'@'localhost' IDENTIFIED BY '$ncuserPW' WITH GRANT OPTION"
mysql -e "FLUSH PRIVILEGES"
echo "Die Nextcloud-Datenbank heisst: nextcloud" >> /var/log/nc-install-log.txt
echo "Der Nextcloud-Datenbank Benutzer heisst: ncuser" >> /var/log/nc-install-log.txt
echo "Hier ist das Nextcloud-Datenbank Passwort: $ncuserPW" >> /var/log/nc-install-log.txt
echo "Die Datenbank wurde erstellt"

sleep 5
#----------------------------------------------------------------
# Nextcloud installieren

mkdir /nextcloud
mkdir /nextcloud/data
chown www-data:www-data /nextcloud/data
apt-get install unzip -y
cd /nextcloud/
rm /var/www/html/index.html
rmdir /var/www/html
wget https://download.nextcloud.com/server/releases/nextcloud-15.0.7.zip
unzip nextcloud-15.0.7.zip -d /var/www/
chown -R www-data:www-data /var/www/nextcloud
rm /nextcloud/nextcloud-15.0.7.zip

touch /etc/apache2/sites-available/nextcloud.conf
echo '<VirtualHost *:80>' >> /etc/apache2/sites-available/nextcloud.conf
echo '        ServerAdmin webmaster@localhost' >> /etc/apache2/sites-available/nextcloud.conf
echo '        DocumentRoot /var/www/nextcloud' >> /etc/apache2/sites-available/nextcloud.conf
echo '        ErrorLog ${APACHE_LOG_DIR}/error.log' >> /etc/apache2/sites-available/nextcloud.conf
echo '        CustomLog ${APACHE_LOG_DIR}/access.log combined' >> /etc/apache2/sites-available/nextcloud.conf
echo '</VirtualHost>' >> /etc/apache2/sites-available/nextcloud.conf
a2dissite 000-default.conf
a2ensite nextcloud.conf
systemctl reload apache2

touch /var/www/nextcloud/config/autoconfig.php
chown www-data:www-data /var/www/nextcloud/config/autoconfig.php
ncadminPW=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)
echo '<?php' >> /var/www/nextcloud/config/autoconfig.php
echo '$AUTOCONFIG = array(' >> /var/www/nextcloud/config/autoconfig.php
echo '  "directory"     => "/nextcloud/data",' >> /var/www/nextcloud/config/autoconfig.php
echo '  "dbtype"        => "mysql",' >> /var/www/nextcloud/config/autoconfig.php
echo '  "dbname"        => "nextcloud",' >> /var/www/nextcloud/config/autoconfig.php
echo '  "dbuser"        => "ncuser",' >> /var/www/nextcloud/config/autoconfig.php
echo '  "dbpass"        => "'$ncuserPW'",' >> /var/www/nextcloud/config/autoconfig.php
echo '  "dbhost"        => "localhost",' >> /var/www/nextcloud/config/autoconfig.php
echo '  "adminlogin"    => "'$ncadminPW'",' >> /var/www/nextcloud/config/autoconfig.php
echo '  "adminpass"     => "PW4ncadmin!",' >> /var/www/nextcloud/config/autoconfig.php
echo ');' >> /var/www/nextcloud/config/autoconfig.php
echo "Das Nextcloud Web-Login lautet: ncadmin" >> /var/log/nc-install-log.txt
echo "Das Nextcloud Web-Passwort lautet: $ncadminPW" >> /var/log/nc-install-log.txt

echo "Nextcloud wurd erfolgreich installiert" >> /var/log/nc-install-log.txt
echo "Nextcloud wurd erfolgreich installiert"
echo "Legen sie die Passwörter aus dem /var/log/nc-install.txt File im KeePass ab und löschen sie die Datei"