#!/bin/bash
mkdir /tmp/miep
touch /tmp/malware.tmp
for i in `/usr/bin/python /usr/local/bin/ml.py`; do mkdir -p /tmp/miep/$i; done
ls /tmp/miep/ > /tmp/malware.tmp
diff -a /etc/squid3/Malware-domains.txt /tmp/malware.tmp >> /tmp/diff.tmp
patch /etc/squid3/Malware-domains.txt /tmp/diff.tmp
rm /tmp/malware.tmp /tmp/diff.tmp
rm -rf /tmp/miep
echo "keke done!"
