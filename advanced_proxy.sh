#!/bin/bash

###This script will setup the squid/privoxy/tor setup i found @
#
# http://mightycomputers.wordpress.com/2012/09/10/recently-i-foun/
# Please read the article and make a backup of your system before running
# this script.
#
# Basically it sets up one squid instance with 8 privoxy and tor workers to
# speed up connection times.
#
# Diagram:
#
#             | privoxy1 --- tor1 ---|
#             | privoxy2 --- tor2 ---|
#             | privoxy3 --- tor3 ---|
#  Squid -----| privoxy4 --- tor4 ---|----WWW
#             | privoxy5 --- tor5 ---|
#             | privoxy6 --- tor6 ---|
#             | privoxy7 --- tor7 ---|
#             | privoxy8 --- tor8 ---|
#
#
# For ez deployment make sure you change the ip address for your local network
# in the res/squid.conf settings file to suit your local config before running this script.
#
# Written and tesrted on Ubuntu server 12.04 LTS
# Does not work out of the box for 14.04!!
#
# After installing test the setup by using these commands @ the terminal:
#
# 1 - Register the proxy in your session env
#
# export http_proxy='http://ip.of.your.proxy:3400
#
# 2 - Query for your ip a few times, result should be a differebt one each time
#
# wget -q -O - checkip.dyndns.org | sed -e 's/.*Current IP Address: //' -e 's/<.*$//'
#
# 3 - Remove the http_proxy from the env
#
# unset http_proxy
#
#
# Bonus points: Automate the update-domains.sh script to update the file
# holding the ip's/domains to be blocked by squid by adding it to cron.
# This script makes a copy of the scripts needed to these paths:
#
#  /usr/local/bin/my.pl - reads the ip's/domainnames from webservice
#  /usr/local/bin/update-domains.sh - uses my.pl to generate the file
#  /etc/squid3/Malware-domains.txt
#
#
# Should you find bugs/general weirdness feel free to contact me
# mail: jan.duprez@gmail.com
# github: https://github.com/jake9050
#
# Enjoy your anonimized/filtered browsing experience!



function apt_install() {
  #update apt and install packages
  apt-get update
  apt-get install tor squid privoxy
}

function services() {
  #Call with start or stop as argv
  if [[ -z $1 ]]; then
    echo "Call services with start or stop"
  fi

  if [[ $1 == 'stop' ]]; then
    #stop services so we can edit configs safely
    echo "Stopping services tor, squid and privoxy"
    service squid3 $1
    service privoxy $1
    service tor $1
  fi

  if [[ $1 == 'start' ]]; then
    echo "Starting services tor, squid and privoxy"
    service squid3 $1
    service privoxy $1
    service tor $1
  fi
}


########Tor config#########

function config_tor() {
  #Backup original
  mv /etc/tor/torrc /tmp/torrc.bak

  #Tor config file generation
  #Create basic settings for all 8 Tor instances - files torrc-1 to torrc-8
  COUNT=1
  while [[ $COUNT -le 8 ]]; do
  echo -e "SocksBindAddress 127.0.0.1 # accept connections only from localhost
AllowUnverifiedNodes middle,rendezvous
Log notice syslog
RunAsDaemon 1
User debian-tor
CircuitBuildTimeout 30
NumEntryGuards 6
KeepalivePeriod 60
NewCircuitPeriod 15"  > torrc-$COUNT

  if [[ $COUNT -eq 1 ]]; then
    echo -e "SocksPort 9050 # port to open for local application connections
DataDirectory /var/lib/tor$COUNT
PidFile /var/run/tor/tor-$COUNT.pid" >> torrc-$COUNT
  fi

  if [[ $COUNT -gt 1 ]]; then
    VAR=$(($COUNT-1))
    PORT=9$VAR\50
    echo -e "SocksPort $PORT # port to open for local application connections
DataDirectory /var/lib/tor$COUNT
PidFile /var/run/tor/tor-$COUNT.pid" >> torrc-$COUNT
  fi
  ((COUNT++))
  done
  mv torrc-* /etc/tor/
}

function create_tor_libs() {
 #Install the lib folders for the 8 Tor instances
 COUNT=1
 while [[ $COUNT -le 8 ]]; do
 install -o debian-tor -g debian-tor -m 700 -d /var/lib/tor$COUNT
 ((COUNT++))
 done
}

function replace_tor_init() {
  #Make backup copy of original file just in case
  cp /etc/init.d/tor /etc/init.d/tor.bak
  #Replace contents of file
  cat res/tor.txt > /etc/init.d/tor
}


#######Privoxy config#######

function config_privoxy() {

  #move original config file
  mv /etc/privoxy/config config.bak

  #Privoxy config file generation
  #Create basic settings for all 8 Privoxy instances - files config-1 to config-8
  LISTEN=(8118 8129 8230 8321 8421 8522 6823 8724)
  COUNT=1
  while [[ $COUNT -le 8 ]]; do
  cat res/privoxy_base > config-$COUNT

  #Set logdir listen-address and socks per configfile
    VAR=$(($COUNT-1))
    LOGFILE="logdir  /var/log/privoxy$COUNT"
    SOCKNUM=9$VAR\50
    SOCK="127.0.0.1:$SOCKNUM"
    echo $LOGFILE >> config-$COUNT
    LISTEN="listen-address  localhost:${LISTEN[$VAR]}"
    echo $LISTEN >> config-$COUNT
    echo "forward-socks5 / $SOCK ." >> config-$COUNT
    mkdir /var/log/privoxy$COUNT
  ((COUNT++))
  done
  mv config-* /etc/privoxy/
}


function create_privoxy_libs() {
 #Install the lib folders for the 8 Privoxy instances
 COUNT=1
 while [[ $COUNT -le 8 ]]; do
 install -o privoxy -g nogroup -m 750 -d /var/lib/privoxy$COUNT
 mkdir /var/log/privoxy$COUNT
 chown -R privoxy.adm /var/log/privoxy$COUNT
 chmod -R 644  /var/log/privoxy$COUNT
 ((COUNT++))
 done
}


function replace_privoxy_init() {
  #Make backup copy of original file just in case
  cp /etc/init.d/privoxy /etc/init.d/privoxy.bak
  #Replace contents of file
  cat res/privoxy.txt > /etc/init.d/privoxy
}


#########Squid config##########

function config_squid() {

mv /etc/squid3/squid.conf /etc/squid3/squid.bak
cp res/squid.conf /etc/squid3/squid.conf
chown root.root /etc/squid3/squid.conf
}

function squid_cache() {
 install -o proxy -g proxy -m 755 -d /home/squid-cache
}


###### Hosts file setup #######
#
# Makes backup to /etc/hosts.bak before manipulating
# Checks if entries for localhost2 to localhost8 are present
# and adds them if not found.

function hosts() {
  cp $1 $1.bak
  for i in {2..8}; do
  res=$(grep -E localhost$i $1 | awk '{print $2}')
    if [[ $res == "localhost$i" ]]; then
      echo "Entry for localhost$i found, not adding it again"
    else
      echo "No entry for localhost$i found, adding it now"
      echo "localhost$i" >> $1
    fi
  done
}

#######Malware domains#######
#
# Run the scripts that fetch the known bad domains from webservice
# for use in squid acl filtering

function malware() {
  touch /etc/squid3/Malware-domains.txt
  cp res/ml.py /usr/local/bin/
  cp res/update-domains.sh /usr/local/bin/
  chmod +x /usr/local/bin/update-domains.sh
  /usr/local/bin/./update-domains.sh
}


### Go! ###

# Update apt & install packages
apt_install

# Stop the services after installing (they autorun on Ubuntu)
services stop

# Tor config
echo "Configuring tor workers"
config_tor
create_tor_libs
replace_tor_init

# Privoxy config
echo "Congiguring privoxy workers"
config_privoxy
create_privoxy_libs
replace_privoxy_init

# Squid config
echo "Configuring squid"
config_squid
squid_cache

# Hosts entries
echo "Configuring /etc/hosts"
hosts /etc/hosts

# Create the malwaredomains file for squid filtering
echo "Creating Malware-domains.txt file in /etc/squid3/"
malware

# Run all services
echo "Config work done, restarting all services"
services start

echo -e "\nAll Done - you should now be able to test the setup\n"
echo "Execute these commands and check if the ip returned changes on each request"
echo "1 - Register the proxy in your session env"
ip=$(ifconfig | grep 'inet addr' | head -n1 | awk '{print $2}' | cut -d: -f2)
echo "export http_proxy='http://$ip:3400'"
echo "2 - Request your ip from checkip.dyndns.org"
echo -e "wget -q -O - checkip.dyndns.org | sed -e 's/.*Current IP Address: //' -e 's/<.*$//'"
echo "3 - Optional - remove the proxy from your session env"
echo "unset http_proxy"
