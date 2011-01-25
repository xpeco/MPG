#!/usr/bin/perl
use strict;
use warnings;

use MPG::MPGMail;

my $env=MPGMail->new(-account=>'123');

#my @protocols = $env->{sender}->QueryAuthProtocols();
#print "$protocols[0]\n";

$env->loop(-verbose=>1);
$env->closeconn;
