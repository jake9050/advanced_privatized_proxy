advanced_proxy
==============

Sets up one squid + 8 privoxy + 8 tor workers for relatively fast/private surfing



This script will setup the squid/privoxy/tor setup i found @

 http://mightycomputers.wordpress.com/2012/09/10/recently-i-foun/
 Please read the article and make a backup of your system before running
 this script.

 Basically it sets up one squid instance with 8 privoxy and tor workers to
 speed up connection times.

 Diagram:

             | privoxy1 --- tor1 ---|
             | privoxy2 --- tor2 ---|
             | privoxy3 --- tor3 ---|
 Squid ------| privoxy4 --- tor4 ---|----WWW
             | privoxy5 --- tor5 ---|
             | privoxy6 --- tor6 ---|
             | privoxy7 --- tor7 ---|
             | privoxy8 --- tor8 ---|


 For ez deployment make sure you change the ip address for your local network
 in the res/squid.conf settings file to suit your local config before running this script.

 Written and tesrted on Ubuntu server 12.04 LTS
 Does not work out of the box for 14.04!!

 After installing test the setup by using these commands @ the terminal:

 1 - Register the proxy in your session env

 export http_proxy='http://ip.of.your.proxy:3400'

 2 - Query for your ip a few times, result should be a different one each time

 wget -q -O - checkip.dyndns.org | sed -e 's/.*Current IP Address: //' -e 's/<.*$//'

 3 - Remove the http_proxy from the env

 unset http_proxy


 Bonus points: Automate the update-domains.sh script to update the file
 holding the ip's/domains to be blocked by squid by adding it to cron.
 This script makes a copy of the scripts needed to these paths:

  /usr/local/bin/my.pl - reads the ip's/domainnames from webservice
  /usr/local/bin/update-domains.sh - uses my.pl to generate the file
  /etc/squid3/Malware-domains.txt


 Should you find bugs/general weirdness feel free to contact me
 mail: jan.duprez@gmail.com
 github: https://github.com/jake9050

 Enjoy your anonimized/filtered browsing experience!
