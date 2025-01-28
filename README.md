# certchecker
Written for MacOS

Bash script to check validity of website certificates provided via list. Outputs the site, cert exp date, days remaining, status, cert authority.  Output is grouped.


Download bash script, drop it in safe place ~/Documents/Scripts is usually a good idea
Make executable: chmod +x certcheck.sh

Populate the url.txt with your desired urls, each on a new line.
examples included
https://google.com
facebook.com
www.amazon.com
https://wikipedia.org


# how to run
./certcheck.sh urls.txt

# Sample output

SSL Certificate Status Report

Domain                                    Expiry           Days      Status        Certificate Authority              
------------------------------------------------------------------------------------------------------------------------
Script is running...
Checking SSL for domain: test.one.com
Checking SSL for domain: test.two.net
Checking SSL for domain: test.three.org
Checking SSL for domain: test.four.biz


Valid Certificates:
test.four.biz                             2025-10-14       259       Valid         DigiCert Inc                       
                                         

Warning Certificates:
test.three.org                            2025-02-11       14        WARNING       DigiCert Inc                                          

Expired Certificates:
test.two.net                              2024-02-01       -102      Expired       DigiCert Inc 

Error Certificates:
test.one.com                              Error            N/A       Error         N/A                                
                               

Color Key:
Valid - More than 30 days until expiration
WARNING - Less than 30 days until expiration
EXPIRED - Certificate has expired

Script has completed.


