#!/bin/bash

###This script will setup the squid/privoxy/tor setup i found @
#
# http://mightycomputers.wordpress.com/2012/09/10/recently-i-foun/
#
# Please read the article and make a backup of your system befor running
# this script.
#
# Make sure you change the ip address for your local network in the squid.conf
# settings to suit your local config
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
    service tor $1
    squid3 $1
    service privoxy $1
  fi

  if [[ $1 == 'start' ]]; then
    echo "Starting services tor, squid and privoxy"
    service tor $1
    squid3 $1
    service privoxy $1
  fi
}


########Tor config#########

function config_tor() {
  #Goto tor dir and rename original torrc file
  #Uncomment after testing
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
    echo -e "SocksPort 9050 # what port to open for local application connections
DataDirectory /var/lib/tor$COUNT
PidFile /var/run/tor/tor-$COUNT.pid" >> torrc-$COUNT
  fi

  if [[ $COUNT -gt 1 ]]; then
    VAR=$(($COUNT-1))
    PORT=9$VAR\50
    echo -e "SocksPort $PORT # what port to open for local application connections
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
  cp /etc/init.d/tor /tmp/tor_init.d.orig
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
    echo "forward-sock5 / $SOCK ." >> config-$COUNT
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
  cp /etc/init.d/privoxy privoxy.orig
  #Replace contents of file
  cat res/privoxy.txt > /etc/init.d/privoxy
}


#########Squid config##########

function config_squid() {

mv /etc/squid3/squid.conf /tmp/squid.bak

echo -e "acl all src all
acl manager proto cache_object
acl localhost src 127.0.0.1/32
acl home_network src 192.168.0.0/24
acl to_localhost dst 127.0.0.0/8
acl SSL_ports port 443
acl Safe_ports port 80 # http
acl Safe_ports port 21 # ftp
acl Safe_ports port 443 # https
acl Safe_ports port 70 # gopher
acl Safe_ports port 210 # wais
acl Safe_ports port 1025-65535 # unregistered ports
acl Safe_ports port 280 # http-mgmt
acl Safe_ports port 488 # gss-http
acl Safe_ports port 591 # filemaker
acl Safe_ports port 777 # multiling http
acl Safe_ports port 901 # SWAT
acl purge method PURGE
acl CONNECT method CONNECT
http_access allow home_network
http_access allow manager localhost
http_access deny manager
http_access allow purge localhost
http_access deny purge
http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports
acl malware_domains url_regex '/etc/squid3/Malware-domains.txt'
http_access deny malware_domains
http_access allow localhost
http_access deny all
icp_access deny all
http_port 8080
icp_port 0
hierarchy_stoplist cgi-bin ?
refresh_pattern ^ftp: 1440 20% 10080
refresh_pattern ^gopher: 1440 0% 1440
refresh_pattern -i (/cgi-bin/|\?) 0 0% 0
refresh_pattern . 0 20% 4320
cache_peer localhost parent 8118 0 round-robin no-query
cache_peer localhost2 parent 8129 0 round-robin no-query
cache_peer localhost3 parent 8230 0 round-robin no-query
cache_peer localhost4 parent 8321 0 round-robin no-query
cache_peer localhost5 parent 8421 0 round-robin no-query
cache_peer localhost6 parent 8522 0 round-robin no-query
cache_peer localhost7 parent 8623 0 round-robin no-query
cache_peer localhost8 parent 8724 0 round-robin no-query
never_direct allow all
always_direct deny all
acl apache rep_header Server ^Apache
broken_vary_encoding allow apache
forwarded_for off
coredump_dir /home/squid-cache # where squid stores the cache
cache_dir ufs /home/squid-cache 20000 16 256 # cache-size in MB, Directory-Structure 1, Directory-Structure below 1
pid_filename /var/run/squid-in.pid
access_log /var/log/squid/access.squid-in.log
cache_store_log /var/log/squid/store.squid-in.log
cache_log /var/log/squid/cache.squid-in.log" > /etc/squid/squid.conf
}

function squid_cache() {
 install -o proxy -g proxy -m 755 -d /home/squid-cache
}


######Hosts file setup#######

function hosts() {
echo -e "127.0.0.1 localhost
127.0.0.1 localhost2
127.0.0.1 localhost3
127.0.0.1 localhost4
127.0.0.1 localhost5
127.0.0.1 localhost6
127.0.0.1 localhost7
127.0.0.1 localhost8" >> /etc/hosts
}


#######Malware domains#######
function malware() {
  touch /etc/squid/Malware-domains.txt
  tar -xzvf update-domains.tar.gz -C /usr/local/bin
  cp res/ml.py /usr/local/bin/
  cp res/update-domains.sh /usr/local/bin/
  chmod +x /usr/local/bin/update-domains.sh
  /usr/local/bin/./update-domains.sh
}


###Start calling the functions
apt_install

###Stop the services after installing (they autorun on Ubuntu)
services stop

###Tor setup
config_tor
create_tor_libs
replace_tor_init

###Privoxy config
config_privoxy
create_privoxy_libs
replace_privoxy_init

###Squid config
config_squid
squid_cache

###Hosts entries
hosts

#Create the malwaredomains file
malware

services start
