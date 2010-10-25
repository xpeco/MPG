package CWMAIL; # third version, created to work with Google's smtp (TLS)

use strict;
use warnings;
use vars qw($VERSION);

$VERSION='0.3';

use DBI;
use Net::SMTP::TLS;
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
       $self->{smtp}=$records->[0]->{SMTP}; # smtp.gmail.com
       $self->{from}=$records->[0]->{EFROM};
       $self->{ffrom}=$records->[0]->{FEFROM};
       $self->{auth}=$records->[0]->{EAUTH};
       $self->{authid}=$records->[0]->{EAUTHID}; # valid email account
       $self->{authpass}=$records->[0]->{EAUTHPASS}; # valid email password 
       $self->{frequency}=$records->[0]->{Frequency};

       $self->{sender}=new Net::SMTP::TLS($self->{smtp}, Timeout => 60, Port => 587, User => $self->{authid}, Password => $self->{authpass}, Debug => '1');

      if (not defined $self->{sender}){print "Error, can not connect to SMTP using the Config data\n";exit 1;}
}

sub close{
       my $self=shift;
       $self->{db}->disconnect;
       $self->{sender}->quit();
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
   my @attachments;
   while(my $attach=$do->fetchrow_hashref()){
       print "Adding attach:$attach->{Path}\n" if $verbose;
       push(@attachments,$attach->{Path});
   }

   eval{
      $self->{sender}->mail($from);
      $self->{sender}->to($mail->{To});
      $self->{sender}->data();

      my $message = MIME::Lite->new(
  	  From    => $mail->{From},
	  To      => $mail->{To},
	  Subject => $mail->{Subject},
	  Type    =>'multipart/mixed'
	);
			
	# TEXT
      $message->attach(
  	  Type => "TEXT",
	  Data => $mail->{Body}
	);
  
      foreach my $attach(@attachments)
      {
         my @aux=split(/\//,$attach);
         my $file=$aux[-1];
         $attach=~s/$aux[-1]//;
         my $file=$attach;
         $message->attach(
 	     Type  => 'application/octet-stream',
	     Path  => $path,
	     Filename => $file,
	     Disposition => "attachment"
	);
     }
     $self->{sender}->datasend($message->as_string);
     $self->{sender}->dataend();
};

  if($@){
       print "Error, updating the email record\n" if $verbose; 
       my $retry=$mail->{Retry}++;
       $do=$self->{db}->prepare("update `Email_OUT` set Retry=\'$retry\', Status=\'$@\', Time=CURTIME(), Date=CURDATE() where Id=\'$mail->{Id}\'");
       $do->execute;
  }
  else
  {
       print "Mail sent!\n" if $verbose;
       $do=$self->{db}->prepare("update `Email_OUT` set Sent=\'Y\', Status=\'OK\', Time=CURTIME(), Date=CURDATE() where Id=\'$mail->{Id}\'");
       $do->execute;
  }


       #ref($self->{sender}->MailMsg({to=>$mail->{To},replyto=>$mail->{ReplyTo},cc=>$mail->{Cc},bcc=>$mail->{Bcc},subject=>$mail->{Subject},msg=>$mail->{Body},b_charset=>'utf-8',priority=>$mail->{Priority}})) or  print "Error: $Mail::Sender::Error";

}

1;
