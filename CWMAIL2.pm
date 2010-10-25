package MGPMAIL; # <--------- MPG ?

use strict;
use warnings;
use vars qw($VERSION);

$VERSION='0.1';

use DBI;
use Mail::SendEasy;
use XML::Simple;

#use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
#use Mail::CheckUser qw(check_email last_check);

sub new{
       my $class=shift;
       my $self={@_};
       bless($self, $class);
       $self->_init;
       return $self;
}

sub _init{
       my $self=shift;

       $self->{xml}=XMLin('./config.xml');
print "Server: $self->{xml}->{host}\nUser: $self->{xml}->{user}\nPass: you know \nDatabase: $self->{xml}->{database}\nCluster: $self->{xml}->{cluster}\n";

       $self->{db}=DBI->connect("DBI:mysql:$self->{xml}->{database}:$self->{xml}->{host}",$self->{xml}->{user},$self->{xml}->{password});
       if (not $self->{db}){
         print STDERR "Connection to DB failed :-(\n";
         exit(0);
       }
       my $do=$self->{db}->prepare("select * from `Config` where status='Enabled'");
       $do->execute;
       my $records=$do->fetchall_arrayref({});
       $self->{smtp}=$records->[0]->{SMTP};
       $self->{from}=$records->[0]->{EFROM};
       $self->{ffrom}=$records->[0]->{FEFROM};
       $self->{auth}=$records->[0]->{EAUTH};
       $self->{authid}=$records->[0]->{EAUTHID};
       $self->{authpass}=$records->[0]->{EAUTHPASS};
       $self->{frequency}=$records->[0]->{Frequency};

       $self->{sender}=new Mail::SendEasy(smtp=>$self->{smtp},user=>$self->{authid},pass=>$self->{authpass});

      if (not defined $self->{sender}){print "Error, can not be possible to connect to the SMTP using the Config data\n";exit 1;}
}

sub close{
       my $self=shift;
       $self->{db}->disconnect;
       return $self;
}

sub loop{
   my $self=shift;
   my %properties=@_; # rest of params by hash

   my $verbose=0;
   $verbose=$properties{'-verbose'} if defined $properties{'-verbose'};
   print "Waiting for emails on MPG\n" if $verbose;
   while(1){
     my $do=$self->{db}->prepare("select * from `Email_OUT` where Sent<>'Y' and Retry<'10' and Mount='Y' and ClusterId=\'$self->{xml}->{cluster}\'");
     $do->execute;
     while(my $record=$do->fetchrow_hashref()){
          print "Pending email found ($record->{Id})\n" if $verbose;
          $self->send(-email=>$record,-verbose=>$verbose);
     }
     sleep $self->{frequency};
     print "Waiting for emails on MPG\n" if $verbose;
   } 
}

sub send
{
   my $self=shift;
   my %properties=@_; # rest of params by hash

   my $verbose=0;
   $verbose=$properties{'-verbose'} if defined $properties{'-verbose'};
   my $mail;
   if(defined $properties{'-email'})
   {
     $mail=$properties{'-email'};
   }
   else
   {
     print "Error at 'send', the -email parameter is mandatory!\n";
     exit;
   }

   my $do=$self->{db}->prepare("select * from `Email_ATTACHMENTS` where Header=\'$mail->{Id}\'");
   $do->execute;
   my @list;
   while(my $attach=$do->fetchrow_hashref()){
       print "Adding attach:$attach->{Path}\n" if $verbose;
       push(@list,$attach->{Path});
   }
     
   my $status;
   if (@list!=0) # with attachments
   {
       $status = $mail->send(from=>$mail->{From},from_title=>$mail->{ffrom},reply=>$mail->{ReplyTo},to=>$mail->{To},cc=>$mail->{Cc},bcc=>$mail->{Bcc},subject=>$mail->{Subject} ,msg=>$mail->{Body},anex=>@list);
   }
   else
   {
       $status = $mail->send(from=>$mail->{From},from_title=>$mail->{ffrom},reply=>$mail->{ReplyTo},to=>$mail->{To},cc=>$mail->{Cc},bcc=>$mail->{Bcc},subject=>$mail->{Subject} ,msg=>$mail->{Body});

   }

   if(!$status)
   {
       print "Error, updating the email record\n" if $verbose; 
       my $retry=$mail->{Retry}++;
       $do=$self->{db}->prepare("update `Email_OUT` set Retry=\'$retry\', Status=\'$mail->error\', Time=CURTIME(), Date=CURDATE() where Id=\'$mail->{Id}\'");
       $do->execute;
    }
    else
    {
       print "Mail sent!\n" if $verbose;
       $do=$self->{db}->prepare("update `Email_OUT` set Sent=\'Y\', Status=\'OK\', Time=CURTIME(), Date=CURDATE() where Id=\'$mail->{Id}\'");
       $do->execute;
    }
}

#sub _checkaddress
#{
#    my $email=shift @_;
#    my $chk_network=shift @_; # 0 not check 1 check
#    my $debug=shift @_;  # 0 not debug  1 debug

#    my $skip_network_check;

#    $Mail::CheckUser::Skip_Network_Checks=!$skip_network_check; #   if =1 skip, so chk_network must be 0 for skipping  1=!0
#    $Mail::CheckUser::Debug=$debug;

#    my $res;
#    if(check_email($email)){
#       $res= 0;
#    }
#    else {
#       $res=last_check()->{reason};  # return the cause of failure
#    } 
#    return $res;  # returns 0 if OK  or the casuse of the failure
#}
1;
