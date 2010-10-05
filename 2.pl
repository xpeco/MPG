#!/usr/bin/perl
 use Mail::Sender;
 my $sender = new Mail::Sender {smtp => 'smtp.gmail.com'};
 die "Error: $Mail::Sender::Error\n" unless ref $sender;
 print join(', ', $sender->QueryAuthProtocols()),"\n";
