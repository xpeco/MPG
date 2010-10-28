#!/usr/bin/perl
use strict;
use warnings;

use MPGMail;

my $env=MPGMail->new();

#my @protocols = $env->{sender}->QueryAuthProtocols();
#print "$protocols[0]\n";

$env->loop(-verbose=>1);
$env->close;
