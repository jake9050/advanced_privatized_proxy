import re
import urllib2

# download website
request = urllib2.Request('http://www.malwaredomainlist.com/mdl.php?sort=Domain&ascordesc=DESC&search=&colsearch=All&quantity=All')
opener = urllib2.build_opener()
try:
    content = opener.open(request).read()
except:
    print "FAIL!"
    content = ""

re_tr = re.compile('<tr(.*?)</tr>')
re_td = re.compile('<td>(.*?)</td>')

for tr in re_tr.findall(content):
    try:
        tds = re_td.findall(tr)
        domain = tds[1]
        ip = tds[2]
    
        to_out = domain
        if domain == '-':
            to_out = ip

        print to_out.replace("<wbr>", "")
    except:
        pass
