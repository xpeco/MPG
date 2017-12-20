package MPGMail; # fourth version, created to work with Google's smtp (SSL)

use strict;
use warnings;
use vars qw($VERSION);

$VERSION='0.6';

use DBI;
use Net::SMTP::SSL;
use Authen::SASL;
use MIME::Base64;
use File::Spec;
use LWP::MediaTypes;
use XML::Simple;

#use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
#use Mail::CheckUser qw(check_email last_check);

sub new{
       my $class=shift;
       my $self={@_};
       bless($self, $class);
       $self->_initxml;
       $self->_initdb;
       return $self;
}

sub _initxml{
       my $self=shift;
       $self->{xml}=XMLin('/etc/MPG/config.xml');
       print "Server: $self->{xml}->{host}\n
User: $self->{xml}->{user}\n
Pass: you know \n
Database: $self->{xml}->{database}\n
Cluster: $self->{xml}->{cluster}\n";

}

sub _initdb{
       my $self=shift;
       $self->{db}=DBI->connect("DBI:mysql:$self->{xml}->{database}:$self->{xml}->{host}",
       $self->{xml}->{user},
       $self->{xml}->{password});
       
       # Never dies....
       if (not $self->{db}){
         print STDERR "Connection to DB failed :-(\n";
         my $error=1;
         while($error){
          print "Do not worry, trying to reconnect to DB\n";
          sleep 5;
          $self->{db}=DBI->connect("DBI:mysql:$self->{xml}->{database}:$self->{xml}->{host}",
          $self->{xml}->{user},
          $self->{xml}->{password});
          if ($self->{db}){$error=0;}
         }
       }
}
sub _initsmtpconfig{
       my $self=shift;
       my $do=$self->{db}->prepare("select * from `Config` where Status='Enabled'");
       $do->execute;
       my $records=$do->fetchall_arrayref({});
       $self->{smtp}=$records->[0]->{SMTP}; # smtp.gmail.com
       $self->{authid}=$records->[0]->{EAUTHID}; # valid email account
       $self->{authpass}=$records->[0]->{EAUTHPASS}; # valid email password
       $self->{frequency}=$records->[0]->{Frequency}; # frequency between querys
       return $self;
}

sub _initsmtp{
       my $self=shift;
      # my $do=$self->{db}->prepare("select * from `Config` where Status='Enabled'");
      # $do->execute;
      # my $records=$do->fetchall_arrayref({});
      # $self->{smtp}=$records->[0]->{SMTP}; # smtp.gmail.com
      # $self->{authid}=$records->[0]->{EAUTHID}; # valid email account
      # $self->{authpass}=$records->[0]->{EAUTHPASS}; # valid email password
      # $self->{frequency}=$records->[0]->{Frequency}; # frequency between querys

       if (not $self->{sender} = Net::SMTP::SSL->new($self->{smtp},
                                 Port => 465,
                                 Debug => 0)) {die "Could not connect to server\n";
       }

       # Authenticate
       $self->{sender}->auth($self->{authid}, $self->{authpass}) || die "Authentication (SMTP) failed!\n";
       #return $self;
}

sub closeconn{
       my $self=shift;
       $self->{db}->disconnect;
       $self->_closesmtp;
       return $self;
}

sub _closesmtp{
       my $self=shift;
       $self->{sender}->quit();
       return $self;
}

sub loop{
   my $self=shift;
   my %properties=@_; # rest of params by hash

   my $verbose=0;
   $verbose=$properties{'-verbose'} if defined $properties{'-verbose'};
   print "Looking for emails on MPG\n" if $verbose;
   my $tempfrom=''; # store the latest from
   while(1){
      # Let's count the number of messages already sent with the default account
      $self->_initsmtpconfig(); # read config from DB
      $self->{authid}=$tempfrom if ($tempfrom ne ''); # retore latest from used
      my $do;
      $do=$self->{db}->prepare("select count(*) as ALREADY_SENT from `Email_OUT` where sent='Y' and `from`=\'$self->{authid}\' and date=CURRENT_DATE() and clusterid=\'$self->{xml}->{cluster}\' order by id asc");
      if (!$do->execute) { 
         $self->_initdb;
         $do=$self->{db}->prepare("select count(*) as ALREADY_SENT from `Email_OUT` where sent='Y' and `from`=\'$self->{authid}\' and date=CURRENT_DATE() and clusterid=\'$self->{xml}->{cluster}\' order by id asc");
      }
      my $cuenta=$do->fetchrow_hashref();
      my $acumulate=$cuenta->{ALREADY_SENT} // 0;
      print "Registros del día: $acumulate ($cuenta->{ALREADY_SENT})\n";
      my $acc_index=int($acumulate/450);
      $acc_index='' if $acc_index<1;
      $self->{authid}=~s/\@/$acc_index\@/;
      $tempfrom=$self->{authid};
      print "Cuenta de origen: $self->{authid}\n";
      
     $do=$self->{db}->prepare("select * from `Email_OUT` where sent<>'Y' and retry<'10' and mount='Y' and clusterid=\'$self->{xml}->{cluster}\' order by id asc limit 10");
     if (!$do->execute) { $self->_initdb }
     
     if ($do->rows > 0){
        print "Connecting to SMTP server\n" if $verbose;
        $self->_initsmtp;
        while(my $record=$do->fetchrow_hashref()){
             print "Pending email found (Id: $record->{id})\n" if $verbose;
             $record->{from}=$self->{authid}; # overwrite from with the new account
             $self->send(-email=>$record,-verbose=>$verbose);
             print "Sleeping between emails ($self->{frequency})\n";
             sleep $self->{frequency};
        }
        print "Closing connection with SMTP server\n" if $verbose;
        $self->_closesmtp;
     }
     print "Waiting for emails on MPG\n" if $verbose;
     sleep 5;
     
     if (not $self->{db}) {
         print "";
         $self->_initdb;
     }
         
   }
}
sub _createboundry
{
# Create arbitrary frontier text used to seperate different parts of the message
   my ($bi, $bn, @bchrs);
   my $boundry = "";
   foreach $bn (48..57,65..90,97..122) {
     $bchrs[$bi++] = chr($bn);
   }
   foreach $bn (0..20) {
     $boundry .= $bchrs[rand($bi)];
  }
  return $boundry;
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
     #exit;
     return ;
   }

   $mail->{Retry}++;

   my $do=$self->{db}->prepare("select * from `Email_ATTACHMENTS` where header=\'$mail->{id}\'");
   $do->execute;
   
   my $error_attach='NO';
   my @attachments;
   while(my $attach=$do->fetchrow_hashref()){
       print "Adding attach:$attach->{path}\n" if $verbose;
       push(@attachments,$attach->{path});
       unless (-f $attach->{path}) {
           print "Unable to find attachment file $attach->{path}\n" if $verbose;
           $error_attach="Unable to find attachment file $attach->{path}";
           next;
         }
         my $opened=open(FH,"$attach->{path}");
         if( not $opened){
           print "Unable to open attachment file $attach\n" if $verbose;
           $error_attach="Unable to open attachment file $attach->{path}";
         }
   }

  if($error_attach eq 'NO')
  {
    eval{
      my $boundry=_createboundry();

      $self->{sender}->mail($mail->{from}. "\n");

      my @recepients = split(/,/, $mail->{to});
      foreach my $recp (@recepients) {
          $self->{sender}->to($recp . "\n");
      }
      my @ccrecepients = split(/,/, $mail->{cc});
      foreach my $recp (@ccrecepients) {
          $self->{sender}->cc($recp . "\n");
      }
      my @bccrecepients = split(/,/, $mail->{bcc});
      foreach my $recp (@bccrecepients) {
          $self->{sender}->bcc($recp . "\n");
      }
      
      $self->{sender}->data();

      #Send header
      $self->{sender}->datasend("From: " . $mail->{from} . "\n");
      $self->{sender}->datasend("To: " . $mail->{to} . "\n");
      $self->{sender}->datasend("Cc: " . $mail->{cc} . "\n") if $mail->{cc} ne '';
      $self->{sender}->datasend("Reply-To: " . $mail->{replyto} . "\n");
      $self->{sender}->datasend("Subject: " . $mail->{subject} . "\n");

      if(@attachments!=0)
      {
        print "With Attachments\n" if $verbose;
        $self->{sender}->datasend("MIME-Version: 1.0\n");
        $self->{sender}->datasend("Content-Type: multipart/mixed; BOUNDARY=\"$boundry\"\n");

        # Send text body
        $self->{sender}->datasend("\n--$boundry\n");
        $self->{sender}->datasend("Content-Type: text/plain\n");
        $self->{sender}->datasend("\n");
        $self->{sender}->datasend($mail->{body} . "\n\n");
        foreach my $attach(@attachments)
        {
           my($bytesread, $buffer, $data, $total);
           my $opened=open(FH, "$attach");
           binmode(FH);
           while (($bytesread = sysread(FH, $buffer, 1024)) == 1024) {
               $total += $bytesread;
               $data .= $buffer;
           }
           if ($bytesread) {
               $data .= $buffer;
               $total += $bytesread;
           }
           close FH;
           # Get the file name without its directory
           my ($volume, $dir, $fileName) = File::Spec->splitpath($attach);
  
           # Try and guess the MIME type from the file extension so
           # that the email client doesn't have to
           my $contentType = guess_media_type($attach);
           print "Composing MIME with attach $attach\n" if $verbose;
           if ($data) {
                 $self->{sender}->datasend("--$boundry\n");
                 $self->{sender}->datasend("Content-Type: $contentType; name=\"$fileName\"\n");
                 $self->{sender}->datasend("Content-Transfer-Encoding: base64\n");
                 $self->{sender}->datasend("Content-Disposition: attachment; =filename=\"$fileName\"\n\n");
                 $self->{sender}->datasend(encode_base64($data));
                 $self->{sender}->datasend("--$boundry\n");
              }
         }
         $self->{sender}->datasend("\n--$boundry--\n"); # send endboundary end message
      }
      else { # no attach
        print "With No attachments\n" if $verbose;
        $self->{sender}->datasend("MIME-Version: 1.0\n");
        $self->{sender}->datasend("Content-Type: text/plain\n");
        $self->{sender}->datasend("\n");
        $self->{sender}->datasend($mail->{body} . "\n\n");
      }
   
      $self->{sender}->datasend("\n");
      $self->{sender}->dataend();
      print "Sending email\n" if $verbose;

    }; # eval

    if($@){
       print "Warning, updating the email record\n" if $verbose;
       $do=$self->{db}->prepare("update `Email_OUT` set `from`=\'$mail->{from}\', retry=\'$mail->{retry}\', status=\'$@\', mount='N', time=CURTIME(), date=CURDATE() where id=\'$mail->{id}\'");
       $do->execute;
    }
    else
    {
       print "Mail sent!\n" if $verbose;
       $do=$self->{db}->prepare("update `Email_OUT` set `from`=\'$mail->{from}\', sent=\'Y\', status=\'OK\', time=CURTIME(), date=CURDATE() where id=\'$mail->{id}\'");
       $do->execute;
    }
  }
  else{
       print "Updating the email record with Attachment errors\n" if $verbose;
       $do=$self->{db}->prepare("update `Email_OUT` set `from`=\'$mail->{from}\', retry=\'$mail->{retry}\', status=\'$error_attach\', mount='N', time=CURTIME(), date=CURDATE() where id=\'$mail->{id}\'");
       $do->execute;
  }

}

1;
