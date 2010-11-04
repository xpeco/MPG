package MPGMail; # fourth version, created to work with Google's smtp (SSL)

use strict;
use warnings;
use vars qw($VERSION);

$VERSION='0.5';

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
       $self->{xml}=XMLin('./config.xml');
print "Server: $self->{xml}->{host}\nUser: $self->{xml}->{user}\nPass: you know \nDatabase: $self->{xml}->{database}\nCluster: $self->{xml}->{cluster}\n";

}

sub _initdb{
       my $self=shift;
       $self->{db}=DBI->connect("DBI:mysql:$self->{xml}->{database}:$self->{xml}->{host}",$self->{xml}->{user},$self->{xml}->{password});
       if (not $self->{db}){
         print STDERR "Connection to DB failed :-(\n";
         exit(0);
       }
}

sub _initsmtp{
       my $self=shift;

       my $do=$self->{db}->prepare("select * from `Config` where Status='Enabled'");
       $do->execute;
       my $records=$do->fetchall_arrayref({});
       $self->{smtp}=$records->[0]->{SMTP}; # smtp.gmail.com
       $self->{authid}=$records->[0]->{EAUTHID}; # valid email account
       $self->{authpass}=$records->[0]->{EAUTHPASS}; # valid email password 
       $self->{frequency}=$records->[0]->{Frequency};

      if (not $self->{sender} = Net::SMTP::SSL->new($self->{smtp},
                              Port => 465,
                              Debug => 0)) {die "Could not connect to server\n";
      }

     # Authenticate
     $self->{sender}->auth($self->{authid}, $self->{authpass})|| die "Authentication failed!\n";

}

sub closeconn{
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
   print "Looking for emails on MPG\n" if $verbose;
   while(1){
     my $do=$self->{db}->prepare("select * from `Email_OUT` where Sent<>'Y' and Retry<'10' and Mount='Y' and ClusterId=\'$self->{xml}->{cluster}\' order by Id asc limit 10");
     $do->execute;
     if ($do->rows > 0){
        print "Connecting to SMTP server\n" if $verbose;
        $self->_initsmtp;
        while(my $record=$do->fetchrow_hashref()){
             print "Pending email found ($record->{Id})\n" if $verbose;
             $self->send(-email=>$record,-verbose=>$verbose);
             print "Sleeping between emails ($self->{frequency})\n";
             sleep $self->{frequency};
        }
        print "Closing connection to SMTP server\n" if $verbose;
        $self->closeconn;
     }
     print "Waiting for emails on MPG ($self->{frequency})\n" if $verbose;
     sleep $self->{frequency};
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
     exit;
   }

   $mail->{Retry}++;

   my $do=$self->{db}->prepare("select * from `Email_ATTACHMENTS` where Header=\'$mail->{Id}\'");
   $do->execute;
   
   my $error_attach='NO';
   my @attachments;
   while(my $attach=$do->fetchrow_hashref()){
       print "Adding attach:$attach->{Path}\n" if $verbose;
       push(@attachments,$attach->{Path});
       unless (-f $attach->{Path}) {
           print "Unable to find attachment file $attach->{Path}\n" if $verbose;
           $error_attach="Unable to find attachment file $attach->{Path}";
           next;
         }
         my $opened=open(FH, "$attach->{Path}");
         if( not $opened){
           print "Unable to open attachment file $attach\n" if $verbose;
           $error_attach="Unable to open attachment file $attach->{Path}";
         }
   }

  if($error_attach eq 'NO')
  {
    eval{
      my $boundry=_createboundry();

      $self->{sender}->mail($mail->{From}. "\n");

      my @recepients = split(/,/, $mail->{To});
      foreach my $recp (@recepients) {
          $self->{sender}->to($recp . "\n");
      }
      my @ccrecepients = split(/,/, $mail->{Cc});
      foreach my $recp (@ccrecepients) {
          $self->{sender}->cc($recp . "\n");
      }
      my @bccrecepients = split(/,/, $mail->{Bcc});
      foreach my $recp (@bccrecepients) {
          $self->{sender}->bcc($recp . "\n");
      }
      
      $self->{sender}->data();

      #Send header
      $self->{sender}->datasend("From: " . $mail->{From} . "\n");
      $self->{sender}->datasend("To: " . $mail->{To} . "\n");
      $self->{sender}->datasend("Cc: " . $mail->{Cc} . "\n") if $mail->{Cc} ne '';
      $self->{sender}->datasend("Reply-To: " . $mail->{Replyto} . "\n");
      $self->{sender}->datasend("Subject: " . $mail->{Subject} . "\n");

      if(@attachments!=0)
      {
        print "With Attachments\n" if $verbose;
        $self->{sender}->datasend("MIME-Version: 1.0\n");
        $self->{sender}->datasend("Content-Type: multipart/mixed; BOUNDARY=\"$boundry\"\n");

        # Send text body
        $self->{sender}->datasend("\n--$boundry\n");
        $self->{sender}->datasend("Content-Type: text/plain\n");
        $self->{sender}->datasend("\n");
        $self->{sender}->datasend($mail->{Body} . "\n\n");
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
        $self->{sender}->datasend($mail->{Body} . "\n\n");
      }
   
      $self->{sender}->datasend("\n");
      $self->{sender}->dataend();
      print "Sending email\n" if $verbose;

    }; # eval

    if($@){
       print "Warning, updating the email record\n" if $verbose; 
       $do=$self->{db}->prepare("update `Email_OUT` set Retry=\'$mail->{Retry}\', Status=\'$@\', Time=CURTIME(), Date=CURDATE() where Id=\'$mail->{Id}\'");
       $do->execute;
    }
    else
    {
       print "Mail sent!\n" if $verbose;
       $do=$self->{db}->prepare("update `Email_OUT` set Sent=\'Y\', Status=\'OK\', Time=CURTIME(), Date=CURDATE() where Id=\'$mail->{Id}\'");
       $do->execute;
    }
  }
  else{
       print "Updating the email record with Attachment errors\n" if $verbose; 
       $do=$self->{db}->prepare("update `Email_OUT` set Retry=\'$mail->{Retry}\', Status=\'$error_attach\', Time=CURTIME(), Date=CURDATE() where Id=\'$mail->{Id}\'");
       $do->execute;
  }

}

1;
