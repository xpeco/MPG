#!/usr/bin/perl
use strict;
use warnings;

use Getopt::Std;
use DBI;
use XML::Simple;

sub help
{
  print "\nMPG - Multi Protocol Gateway\n";
  print "Version: XX\n";
  print "\nUsage:\n";
  print "\n(r)equired arguments\n\n";
  print " -a [filename]\t\t'Attachment': Single filename or multiple comma separated files to be attached.\n";
  print " -b \"Text\"\t(r)\t'Body': The main text of the e-mail. If more than one word, must be enclosed \n\t\t\tbetween single quotes (\').\n";
  print " -c\t\t\t'Class' of the e-mail. It's just 'tag' to clasify groups of e-mails.\n";
  print " -d [filename]\t\tReads addresses and attachments from a CSV file. See sample.csv.\n";
  print " -f\t\t(r)\t'From': e-mail address from which the e-mail will be sent. Must be correctly configured\n";
  print "\t\t\tin table 'Config'.\n";
  print " -r\t\t\t'ReplyTo': Reply-to address.\n";
  print " -s\t\t(r)\t'Subject': Subject of the e-mail.\n";
  print " -t\t\t(r)\t'To': Destination e-mail address. Supports multiple comma-separated destinations.\n";
  print "\n";
  exit;
}

if ($#ARGV<0){help;exit;} # if no args, just show the usage help and exit

my %options=();

getopts("hf:t:r:s:b:d:c:a:",\%options);

help if defined $options{h};

# Default values
my $subject=' ';
my $from='';
my $to='';
my $reply='';
my $body=' ';
my $file='';
my $class='NONE';
my $attachment='';


$from=$options{f} if defined $options{f};
$subject=$options{s} if defined $options{s};
$to=$options{t} if defined $options{t};
$reply=$options{r} if defined $options{r};
$body=$options{b} if defined $options{b};
$file=$options{d} if defined $options{d};
$class=$options{c} if defined $options{c};
$attachment=$options{a} if defined $options{a};

if ($reply eq ''){$reply=$from;}

# Create DB connection
my $xml=XMLin('./config.xml');
print "Server: $xml->{host}\nUser: $xml->{user}\nPass: you know\nCluster:$xml->{cluster}";

    my $db=DBI->connect("DBI:mysql:$xml->{database}:$xml->{host}",$xml->{user},$xml->{password});
    if (not $db){
         print STDERR "Connection to DB failed :-(\n";
         exit(0);
    }

if($file eq '') # No CSV specified
{
    print "Inserting Email\n";
    print "    Inserting header...";
    my $query="insert into Email_OUT set `From`=\'$from\', `ReplyTo`=\'$reply\', `Subject`=\'$subject\', `To`=\'$to\', `Mount`=\'Y\', `ClusterId`=\'$xml->{cluster}\', `Body`=\'$body\', `Class`=\'$class\'";
    my $do=$db->prepare("$query")->execute;
    print "OK\n";
    print "     Inserting attachment(s) (if any)...";
    if ($attachment ne ''){
      print "Getting header:";
      $query="select LAST_INSERT_ID() as HEADER";
      $do=$db->prepare("$query")->execute;
      my $headers=$do->fetchwrow_hashref();
      print "$headers->{HEADER}\n";
      my @attachment_list=split(/,/,$attachment);
      foreach my $attach(@attachment_list){
        print "Inserting attachment: $attach\n";
        $query="insert into Email_ATTACHMENTS set `Path`=\'$attach\',`Header`=$headers->{HEADER}";
        $do=$db->prepare($query)->execute;
      }
    }
    print "OK\n";
}
else 
{
  # CSV file specified
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
     print "Inserting Email Attachment(s)...";
     $query="insert into Email_ATTACHMENTS set `Path`=\'$fields[1]\',`Header`=LAST_INSERT_ID()";
     $do=$db->prepare($query)->execute;
     print "OK\n";
  }
}
print "Work done (I hope ;-)\n";
$db->disconnect;

