#!/bin/bash

####################################################################################################
# Config
####################################################################################################

CWD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

LOG="/root/puppet.log"
PASSWORD="tester"
EMAIL="david.m.oneill@intel.com"
USEPROXY=1
PROXY="cache"
SEARCH="ir.intel.com"
PROXYFQDN="$PROXY.$SEARCH"
PROXYPORT="911"
HOSTNAME=`hostname -f`
PUPPETHOST="puppet.$SEARCH"

####################################################################################################
# Reboot
####################################################################################################

function Reboot
{
	LogSection "Reboot"
	LogLine "Rebooting"
	reboot
}

####################################################################################################
# Log line
####################################################################################################

function LogLine
{
	echo "$1..." >> $LOG 2>&1
}

####################################################################################################
# Logsection header
####################################################################################################

function LogSection
{
	echo "$1..."
	LogLine "$1"
	LogLine "######################################################################################"
}

####################################################################################################
# Enable Service 
####################################################################################################

function EnableService
{
	LogLine "> ENABLESERVICE: $1"
	update-rc.d $1 defaults >> $LOG 2>&1
	sleep 1
}

####################################################################################################
# Remove Service 
####################################################################################################

function RemoveService
{
	LogLine "> REMOVESERVICE: $1"
	update-rc.d -f $1 remove >> $LOG 2>&1
	sleep 1
}

####################################################################################################
# Restart Service 
####################################################################################################

function RestartService
{
	LogLine "> RESTARTSERVICE: $1"
	echo "restart $1" >> $LOG 2>&1
	service $1 restart > /dev/null 2>&1
	/etc/init.d/$1 restart > /dev/null 2>&1
	sleep 3
}

####################################################################################################
# Stop Service 
####################################################################################################

function StopService
{
	LogLine "> STOPSERVICE: $1"
	service $1 status > /dev/null 2>&1
	
	if [[ $? -eq 0 ]]; then
		service $1 stop >> $LOG 2>&1
		sleep 2
	else
		if [ -f /etc/init.d/$1 ]; then
			/etc/init.d/$1 stop >> $LOG 2>&1
			sleep 2
		fi
	fi
}

####################################################################################################
# Install package
####################################################################################################

function InstallPackage
{
	LogLine "> INSTALLPACKAGE: $1"
	DEBIAN_FRONTEND=noninteractive apt-get -y --allow-unauthenticated --force-yes install $1 >> $LOG 2>&1
	sleep 1
}

####################################################################################################
# Install local package
####################################################################################################

function InstallLocalPackage
{
	LogLine "> INSTALLLOCALPACKAGE: $1"
	dpkg -i $1 >> $LOG 2>&1
	sleep 1
}

####################################################################################################
# ReInstall package
####################################################################################################

function ReinstallPackage
{
	LogLine "> REINSTALLPACKAGE: $1"
	DEBIAN_FRONTEND=noninteractive apt-get -y --allow-unauthenticated --force-yes install --reinstall $1 >> $LOG 2>&1
	sleep 1
}

####################################################################################################
# Remove package
####################################################################################################

function RemovePackage
{
	LogLine "> REMOVEPACKAGE: $1"
	apt-get -y remove $1 >> $LOG 2>&1
	sleep 1
}

####################################################################################################
# Remove package
####################################################################################################

function AutoRemovePackages
{
	LogLine "> REMOVEPACKAGE: $1"
	apt-get -y autoremove >> $LOG 2>&1
	sleep 1
}

####################################################################################################
# Update packages
####################################################################################################

function UpdatePackages
{
	LogLine "> UPDATEPACKAGES"
	apt-get clean all >> $LOG 2>&1
	apt-get -y update >> $LOG 2>&1
	apt-get -y upgrade >> $LOG 2>&1
	apt-get -y dist-upgrade >> $LOG 2>&1
	
	sleep 1
}

####################################################################################################
# Configure Proxy
####################################################################################################

function EnableProxy
{
	if [[ $USEPROXY -eq 1 ]]; then
		WriteConfig "/root/.wgetrc" "http_proxy=http://$PROXYFQDN:$PROXYPORT\nhttps_proxy=http://$PROXYFQDN:$PROXYPORT"
		WriteConfig "/etc/apt/apt.conf" "Acquire::http::Proxy \"http://$PROXYFQDN:$PROXYPORT/\";\nAcquire::https::Proxy \"http://$PROXYFQDN:$PROXYPORT/\";"		
	fi	

	proxyhost=""

	if [[ $USEPROXYHOSTS -eq 1 ]]; then
		proxyhost="$PROXYIP $PROXYFQDN $PROXY"
	fi
}

####################################################################################################
# Read Config Template
####################################################################################################

function ReadConfig
{
	LogLine "> READCONFIG: $1"
	IN=""

	while read LINE; do
		if [[ "$LINE" =~ ^\# || ! "$LINE" =~ \$ ]]; then
			CONTENT="$LINE"
		else
			CONTENT=$(eval echo "$LINE")
		fi
		IN=$(printf "%s%s" "$IN" "$CONTENT\n")
	done < $1

	echo "$IN"
}

####################################################################################################
# Write Config Template
####################################################################################################

function WriteConfig
{
	LogLine "> WRITECONFIG: $1"
	if [ ! -f "$1" ]; then
		touch "$1"
	fi

	echo -e "$2" > $1
}

####################################################################################################
# backup Config Template
####################################################################################################

function BackupConfig
{
	LogLine "> BACKUPCONFIG: $1"
	if [ ! -f "$1" ]; then
		touch "$1"
	else
		cp -v $1 $1.bak >> $LOG 2>&1
	fi
}

####################################################################################################
# Replace in config
####################################################################################################

function ReplaceInConfig
{
	LogLine "> REPLACEINCONFIG: $2 $3"
	echo -e "$1" | perl -lpe "s/$2/$3/g"
}

####################################################################################################
# Append to config
####################################################################################################

function AppendToConfig
{
	LogLine "> APPENDTOCONFIG: $1 $2"
	echo -e "$2" >> $1
}

####################################################################################################
# Download file
####################################################################################################

function DownloadFile
{
	LogLine "> DOWNLOADFILE: $1"
	wget $1 >> $LOG 2>&1	
}

####################################################################################################
# Copy File
####################################################################################################

function Copy
{
	cp -rv $1 $2 >> $LOG 2>&1
}

####################################################################################################
# ConfigureNtp
####################################################################################################

function ConfigureNtp
{
	LogSection "Installing ntp"
	InstallPackage "ntp"

	BackupConfig "/etc/ntp.conf"
	CONFIG=$(ReadConfig "/etc/ntp.conf")
	CONFIG=$(ReplaceInConfig "$CONFIG" "server 0.*?.org" "server ntp-host1.$CONTROLLER_EXT_DS")
	CONFIG=$(ReplaceInConfig "$CONFIG" "server 1.*?.org" "server ntp-host2.$CONTROLLER_EXT_DS")
	CONFIG=$(ReplaceInConfig "$CONFIG" "server 2.*?.org" "server ntp-host3.$CONTROLLER_EXT_DS")
	CONFIG=$(ReplaceInConfig "$CONFIG" "server 3.*?.org" '')
	WriteConfig "/etc/ntp.conf" "$CONFIG" 

	RestartService "ntp"
}


####################################################################################################
# ConfigurePuppetMaster
####################################################################################################

function ConfigurePuppetMaster
{
	LogSection "Installing puppetmaster"
	
	InstallPackage "postgresql"
	su - postgres -c "psql -U postgres -d postgres -c \"alter user postgres with password '$PASSWORD';\"" >> $LOG 2>&1
	su - postgres -c "createdb puppetdb" >> $LOG 2>&1
	
	InstallPackage "puppetmaster hiera facter puppetdb puppetdb-terminus pgadmin3 apache2"
	InstallPackage "git build-essential git-core curl ruby ruby1.8-dev rubygems"
	InstallPackage "libcurl4-openssl-dev libssl-dev zlib1g-dev apache2-threaded-dev ruby-dev libapr1-dev libaprutil1-dev"
	
	a2enmod ssl >> $LOG 2>&1
	a2enmod headers >> $LOG 2>&1
	
	WriteConfig "/etc/puppetdb/conf.d/database.ini" "[database]"
	AppendToConfig "/etc/puppetdb/conf.d/database.ini" "classname = org.postgresql.Driver"
	AppendToConfig "/etc/puppetdb/conf.d/database.ini" "subprotocol = postgresql"
	AppendToConfig "/etc/puppetdb/conf.d/database.ini" "subname = //localhost:5432/puppetdb"
	AppendToConfig "/etc/puppetdb/conf.d/database.ini" "log-slow-statements = 10" 
	AppendToConfig "/etc/puppetdb/conf.d/database.ini" "username = postgres"
	AppendToConfig "/etc/puppetdb/conf.d/database.ini" "password = $PASSWORD"

	mkdir -vp /etc/puppet/ssl/{ca/{private,requests,signed},certificate_requests,certs,private_keys,public_keys}  >> $LOG 2>&1
	mkdir -vp /var/lib/puppet/log >> $LOG 2>&1
	touch /var/lib/puppet/log/http.log >> $LOG 2>&1
	touch /var/lib/puppet/log/masterhttp.log >> $LOG 2>&1
	touch /var/lib/puppet/log/puppetmaster.log >> $LOG 2>&1
	touch /var/lib/puppet/log/puppetd.log >> $LOG 2>&1
	touch /var/lib/puppet/log/rails.log >> $LOG 2>&1
	Copy "./etc/puppet/*" "/etc/puppet/"
		
	mkdir -vp /root/.ssh/ >> $LOG 2>&1
	BackupConfig "/root/.ssh/config"
	WriteConfig "/root/.ssh/config" "Host github.intel.com\n    StrictHostKeyChecking no"
	
	RemoveService "puppetmaster"
	EnableService "puppetdb"
	EnableService "postgresql"	
    StopService "puppetmaster"
	EnableService "apache2"

    rm /etc/puppet/environments/.gitignore >> $LOG 2>&1
		
    Copy "./var/lib/puppet/ssl/*" "/var/lib/puppet/ssl/"

	ln -s /var/lib/puppet/ssl/private_keys/$HOSTNAME.pem /var/lib/puppet/ssl/private_keys/puppet.ir.intel.com.pem  >> $LOG 2>&1
	ln -s /var/lib/puppet/ssl/public_keys/$HOSTNAME.pem /var/lib/puppet/ssl/public_keys/puppet.ir.intel.com.pem  >> $LOG 2>&1
	ln -s /var/lib/puppet/ssl/ca/signed/$HOSTNAME.pem /var/lib/puppet/ssl/ca/signed/puppet.ir.intel.com.pem  >> $LOG 2>&1
	ln -s /var/lib/puppet/ssl/certs/$HOSTNAME.pem /var/lib/puppet/ssl/certs/puppet.ir.intel.com.pem >> $LOG 2>&1

	InstallPackage "ruby-fog"

	if [[ $USEPROXY -eq 1 ]]; then
		git config --global http.proxy http://$PROXYFQDN:$PROXYPORT >> $LOG 2>&1
		git config --global https.proxy http://$PROXYFQDN:$PROXYPORT >> $LOG 2>&1	
		export http_proxy=http://$PROXYFQDN:$PROXYPORT
		export https_proxy=$http_proxy		
	fi
	
	gem install guid >> $LOG 2>&1
    gem install r10k >> $LOG 2>&1
	gem install rack >> $LOG 2>&1
	gem install passenger >> $LOG 2>&1
	passenger-install-apache2-module -a >> $LOG 2>&1
	
	if [[ $USEPROXY -eq 1 ]]; then
		git config --global http.proxy "" >> $LOG 2>&1
		git config --global https.proxy "" >> $LOG 2>&1
		export http_proxy=""
		export https_proxy=""
	fi
	
	mkdir -vp /usr/share/puppet/rack/puppetmasterd/{public,tmp} >> $LOG 2>&1
	Copy "/usr/share/puppet/ext/rack/config.ru" "/usr/share/puppet/rack/puppetmasterd/"
	
	updatedb
	STR=$(locate mod_passenger.so | head -n 1 | awk '{split($0,a,"/build"); print a[1]}')
	STR=$(echo $STR | sed -e 's/^ *//g' -e 's/ *$//g')
	STR=$(echo $STR | sed 's/\//\\\//g')
	
	Copy "./etc/apache2/conf.d/puppetmaster.conf" "/etc/apache2/sites-available/"
	Copy "./etc/apache2/conf.d/000-default.conf" "/etc/apache2/sites-available/"
	sed -i "s/PUPPETMASTERFQDN/$PUPPETHOST/g" /etc/apache2/sites-available/puppetmaster.conf
	sed -i "s/PASSENGER/$STR/g" /etc/apache2/sites-available/puppetmaster.conf
	a2ensite puppetmaster >> $LOG 2>&1
	
	touch "/var/log/apache2/"$PUPPETHOST"_ssl_error.log"
	touch "/var/log/apache2/"$PUPPETHOST"_ssl_access.log"
	
	chmod -v 700 /root/.ssh/ >> $LOG 2>&1
	chown -vR puppet:puppet /usr/share/puppet/rack/puppetmasterd/config.ru >> $LOG 2>&1
	chown -vR puppet:puppet /var/lib/puppet >> $LOG 2>&1
	chown -vR puppet:puppet /etc/puppet >> $LOG 2>&1

	rm -rvf /etc/puppetdb/ssl >> $LOG 2>&1
	/usr/sbin/puppetdb-ssl-setup -f >> $LOG 2>&1
	
	WriteConfig "/etc/puppetdb/conf.d/jetty.ini" "[jetty]"
	AppendToConfig "/etc/puppetdb/conf.d/jetty.ini" "host = 0.0.0.0"
	AppendToConfig "/etc/puppetdb/conf.d/jetty.ini" "port = 8080"
	AppendToConfig "/etc/puppetdb/conf.d/jetty.ini" "ssl-host = 0.0.0.0"
	AppendToConfig "/etc/puppetdb/conf.d/jetty.ini" "ssl-port = 8081"
	AppendToConfig "/etc/puppetdb/conf.d/jetty.ini" "ssl-key = /etc/puppetdb/ssl/private.pem"
	AppendToConfig "/etc/puppetdb/conf.d/jetty.ini" "ssl-cert = /etc/puppetdb/ssl/public.pem"
	AppendToConfig "/etc/puppetdb/conf.d/jetty.ini" "ssl-ca-cert = /etc/puppetdb/ssl/ca.pem"

    ln -vs /etc/apache2/mods-available/rewrite.load /etc/apache2/mods-enabled/rewrite.load >> $LOG 2>&1
}

####################################################################################################
# ConfigureR10k
####################################################################################################

function ConfigureR10k
{
	LogSection "Configuring R10k"
	
    Copy "./etc/r10k.yaml" "/etc"
    r10k deploy environment -p
	chown -vR puppet:puppet /etc/puppet >> $LOG 2>&1
}

####################################################################################################
# Facter Meta Data
####################################################################################################

function ConfigureMetaService
{
	LogSection "Meta Data Service"
	rm -rvf /var/www/* >> $LOG 2>&1
    mkdir -vp /var/www/meta/. >> $LOG 2>&1
    Copy "./var/www/.htaccess" "/var/www/"
    Copy "./var/www/meta/*" "/var/www/meta/"
}

####################################################################################################
# Client boot strap
####################################################################################################

function ConfigureClientBootstrapArea
{
	LogSection "Configuring client bootstrap area"
	InstallPackage "git"
	
	mkdir -vp /var/www/bootstrap/ >> $LOG 2>&1
    git clone https://github.intel.com/EC/OC-PuppetClient.git /var/www/bootstrap/ >> $LOG 2>&1
	chown -vR www-data:www-data /var/www >> $LOG 2>&1
}

####################################################################################################
# apt mirror
####################################################################################################

function ConfigureAptRepos
{
	LogSection "Configuring apt mirrors"
	InstallPackage "apt-mirror"
	
	sed -i "s/^deb/#deb/g" /etc/apt/mirror.list
	sed -i "s/^clean/#clean/g" /etc/apt/mirror.list
	
	mkdir -vp /var/www/repos/fuel/ >> $LOG 2>&1
	mkdir -vp /var/www/repos/intel/ >> $LOG 2>&1
	DownloadFile "http://download.mirantis.com/precise-fuel-grizzly/Mirantis.key"
	Copy "Mirantis.key" "/var/www/repos/fuel/"
	Copy "./var/www/meta/*" "/var/www/meta/"
	
	echo "deb http://download.mirantis.com/precise-fuel-grizzly/ precise main" >> /etc/apt/mirror.list
	apt-mirror >> $LOG 2>&1
	Copy "/var/spool/apt-mirror/mirror/download.mirantis.com/precise-fuel-grizzly/*" "/var/www/repos/fuel/"

	InstallPackage "dpkg-dev apache2 dpkg-sig rng-tools"
	rngd -r /dev/urandom
	
	Copy "./root/.gnupg/*" "/root/.gnupg/"
	
	mkdir -vp /var/www/repos/intel/dists/stable/main/binary >> $LOG 2>&1
	Copy "./var/www/repos/intel/*" "/var/www/repos/intel/"
	chown -vR www-data:www-data /var/www >> $LOG 2>&1
}

####################################################################################################
# Pause 
####################################################################################################

function pause()
{
	read -p "Press [Enter] key to continue..."
}

####################################################################################################
# Main
####################################################################################################

function Main
{
	LogSection "System Preparation and Repository Configuration"
	RemovePackage "ufw"
	Copy "./etc/network/interfaces" "/etc/network/interfaces"
	EnableProxy
	DownloadFile "http://apt.puppetlabs.com/puppetlabs-release-saucy.deb"
	InstallLocalPackage "puppetlabs-release-saucy.deb"
	UpdatePackages

	ConfigureNtp
	ConfigurePuppetMaster
    ConfigureR10k
	ConfigureMetaService
	ConfigureAptRepos
    ConfigureClientBootstrapArea	
	reboot
}

Main
