#!/usr/bin/perl
use strict;
use warnings;

use Getopt::Std;
use DBI;
use XML::Simple;

sub help
{
  print "\nVersion: XX\n";
  print "\nUsage:\n";
  print " -b\t\t'Body': The main text of the e-mail.\n";
  print " -r\t\t'ReplyTo': .........\n";
  print " -c\t\t'Class' of the e-mail (optional).\n";
  print " -d [filename]\tReads addresses and attachments from a plain text file. See sample.csv.\n";
  print " -f\t\t'From': e-mail address from which the e-mail will be sent. Must be correctly configured\n";
  print "\t\tin table 'Config'.\n";
  print " -s\t\t'Subject' of the e-mail.\n";
  print " -t\t\t'To': Destination e-mail address. Supports multiple comma-separated destinations.\n";
  print " -a\t\t'Attachment': ....\n";

  print "\n";
  exit;
}

if ($#ARGV<0){help;exit;} # if no args, just show the Help and exit

my %options=();

getopts("hf:t:r:s:b:d:c:a:",\%options);

help if defined $options{h};

# Default values
my $subject='';
my $from='';
my $to='';
my $reply='';
my $body='';
my $file='';
my $class='';
my $attachment='';


$from=$options{f} if defined $options{f};
$subject=$options{s} if defined $options{s};
$to=$options{t} if defined $options{t};
$reply=$options{r} if defined $options{r};
$body=$options{b} if defined $options{b};
$file=$options{d} if defined $options{d};
$class=$options{c} if defined $options{c};
$attachment=$options{a} if defined $options{a};


# Create DB connection
my $xml=XMLin('./config.xml');
print "Server: $xml->{host}\nUser: $xml->{user}\nPass: you know\nCluster:$xml->{cluster}";

    my $db=DBI->connect("DBI:mysql:$xml->{database}:$xml->{host}",$xml->{user},$xml->{password});
    if (not $db){
         print STDERR "Connection to DB failed :-(\n";
         exit(0);
    }

if($file eq '')
{
    print "Inserting Email without CSV\n";
    print "    Inserting header...";
    my $query="insert into Email_OUT set `From`=\'$from\', `ReplyTo`=\'$reply\', `Subject`=\'$subject\', `To`=\'$to\', `Mount`=\'Y\', `ClusterId`=\'$xml->{cluster}\', `Body`=\'$body\', `Clase`=\'$class\'";
    my $do=$db->prepare("$query")->execute;
    print "Ok\n";
    print "     Inserting attachment (if any)...";
    if ($attachment ne ''){
      print "Inserting Email Attachment...";
      $query="insert into Email_ATTACHMENTS set `Path`=\'$attachment\',`Header`=LAST_INSERT_ID()";
      $do=$db->prepare($query)->execute;
    }
    print "OK\n";
}
else
{
# Open file
  print "Reading DB file (separator = ;)\n";
  open(IN,"+<$file")
  or die "ERROR";
  my @file=<IN>;
  foreach my $line(@file)
  {
     print "Inserting Email header...";
     my @fields=split(/;/,$line);
     my $query="insert into Email_OUT set `From`=\'$from\',`Subject`=\'$subject\',`To`=\'$fields[0]\', `ReplyTo`=\'$reply\', `Mount`=\'Y\',`ClusterId`=\'$xml->{cluster}\',`Body`=\'$body\',`Clase`=\'$class\'";
     my $do=$db->prepare($query)->execute;
     print "OK\n";
     print "Inserting Email Attachment...";
     $query="insert into Email_ATTACHMENTS set `Path`=\'$fields[1]\',`Header`=LAST_INSERT_ID()";
     $do=$db->prepare($query)->execute;
     print "OK\n";
  }
}
print "Work done (I hope ;-)\n";
$db->disconnect;

