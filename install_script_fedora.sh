#!/bin/bash
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

#PERLVER=`perl -v | awk '/This/ {print $4}' | sed -e 's/v//'`

echo ""
echo "Creating folders..."
echo ""

echo "/etc/MPG"
	mkdir -p /etc/MPG

echo "/usr/local/lib/perl5/MPG"
	mkdir -p /usr/local/lib/perl5/MPG

echo "/usr/local/bin"
	mkdir -p /usr/local/bin

echo ""
echo "Copying files..."
echo ""

echo "config.xml -> /etc/MPG"
	cp -f config.xml /etc/MPG/

echo "MPGMail.pm -> /usr/local/lib/perl5/MPG"
	cp -f MPGMail.pm /usr/local/lib/perl5/MPG/
	
echo "MPGTwitter.pm -> /usr/local/lib/perl5/MPG"
	cp -f MPGTwitter.pm /usr/local/lib/perl5/MPG	


echo "writemail.pl -> /usr/local/bin"
	cp -f writemail.pl /usr/local/bin/

echo "MPGMail.pl -> /usr/local/bin"
	cp -f MPGDaemon.pl /usr/local/bin/
	
echo "twitter.pl -> /usr/local/bin"
	cp -f twitter.pl /usr/local/bin/	

echo ""
echo "Done."
echo ""
