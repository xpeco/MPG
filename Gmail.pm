#package Email::Send::SMTP::Gmail;
package Gmail;

use strict;
use warnings;
use vars qw($VERSION);

$VERSION='0.5';

use Net::SMTP::SSL;
#use Authen::SASL;
use MIME::Base64;
use File::Spec;
use LWP::MediaTypes;

sub new{
       my $class=shift;
       my $self={@_};
       bless($self, $class);
       my %properties=@_;
       $self->_initsmtp($properties{'-login'},$properties{'-pass'},$properties{'-debug'});
       $self->{from}=$properties{'-login'};
       return $self;
}

sub _initsmtp{
       my $self=shift;
       my $login=shift;
       my $pass=shift;
       my $debug=shift;
       if (not $self->{sender} = Net::SMTP::SSL->new('smtp.gmail.com',
                                 Port => 465,
                                 Debug => $debug)) {die "Could not connect to server\n";
       }
       # Authenticate
       $self->{sender}->auth($login,$pass) || die "Authentication (SMTP) failed!\n";
}

sub bye{
       my $self=shift;
       $self->{sender}->quit();
       return $self;
}

sub _checkfiles
{
       my $attachs=shift;
       my $verbose=shift;
       my @attachments=split(/,/,$attachs);
       foreach my $attach(@attachments)
       {
           unless (-f $attach) {
              print "Unable to find attachment file $attach\n" if $verbose;
              return 0;
           }
           my $opened=open(FH, "$attach");
           if( not $opened){
              print "Unable to open attachment file $attach\n" if $verbose;
              return 0;
           }
       }
       return 1;
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

   $mail->{to}='';
   $mail->{to}=$properties{'-to'} if defined $properties{'-to'};

   $mail->{replyto}=$self->{from};
   $mail->{replyto}=$properties{'-replyto'} if defined $properties{'-replyto'};

   $mail->{cc}='';
   $mail->{cc}=$properties{'-cc'} if defined $properties{'-cc'};

   $mail->{bcc}='';
   $mail->{bcc}=$properties{'-bcc'} if defined $properties{'-bcc'};

   $mail->{subject}='';
   $mail->{subject}=$properties{'-subject'} if defined $properties{'-subject'};

   $mail->{body}='';
   $mail->{body}=$properties{'-body'} if defined $properties{'-body'};

   $mail->{attachments}='';
   $mail->{attachments}=$properties{'-attachments'} if defined $properties{'-attachments'};

    eval{
      my $boundry=_createboundry();

      $self->{sender}->mail($self->{from}. "\n");

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
      $self->{sender}->datasend("From: " . $self->{from} . "\n");
      $self->{sender}->datasend("To: " . $mail->{to} . "\n");
      $self->{sender}->datasend("Cc: " . $mail->{cc} . "\n") if $mail->{cc} ne '';
      $self->{sender}->datasend("Reply-To: " . $mail->{replyto} . "\n");
      $self->{sender}->datasend("Subject: " . $mail->{subject} . "\n");

      if($mail->{attachments} ne '')
      {
        print "With Attachments\n" if $verbose;
        if(_checkfiles($mail->{attachments},$verbose))
        {
           $self->{sender}->datasend("MIME-Version: 1.0\n");
           $self->{sender}->datasend("Content-Type: multipart/mixed; BOUNDARY=\"$boundry\"\n");

           # Send text body
           $self->{sender}->datasend("\n--$boundry\n");
           $self->{sender}->datasend("Content-Type: text/plain\n");
           $self->{sender}->datasend("\n");
           $self->{sender}->datasend($mail->{body} . "\n\n");
        
           my @attachments=split(/,/,$mail->{attachments});
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
         else {exit;} # errors with attachments
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
       print "Warning: $@ \n" if $verbose; 
    }
    else
    {
       print "Mail sent!\n" if $verbose;
    }
}

1;
__END__

=head1 NAME

Email::Send::SMTP::Gmail;

=head1 SYNOPSIS

use Email::Send::SMTP::Gmail;


my $mail=Email::Send::SMTP::Gmail->new( -smtp=>'gmail.com',
                                        -login=>'add_your_address@gmail.com',
                                        -pass=>'add_your_pass');

$mail->send(-to=>'target@xxx.com', -subject=>'Hello!', -verbose=>'1', -body=>'Just testing it', -attachments=>'full_path_to_file');

$mail->bye;

=head1 DESCRIPTION

To be completed...

=over 2 

=item new(-login=>'', -pass=>'' [, -debug=>''])

Creates the object, validating the credentials...

=item send(-to=>'', -subject=>'', -cc=>'', -bcc=>'', -replyto=>'', -body=>'', -attachments=>'')

Compose and send the email..

=item bye
 
Close the SMTP session

=back

=head1 BUGS

Please report any bugs or feature requests to C<bug-email-send-smtp-gmail at rt.cpan.org> or through the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Email-Send-SMTP-Gmail>.
We will be notified, and then you'll automatically be notified of progress on your bug as we make changes.

=head1 AUTHORS

Martin Vukovic, C<< mvukovic at microbotica.es >>
Juan Jose 'Peco' San Martin, C<< <peco at cpan.org> >>

=head1 COPYRIGHT

Copyright 2010 Microbotica

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Email::Send::SMTP::Gmail

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Email-Send-SMTP-Gmail>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Email-Send-SMTP-Gmail>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Email-Send-SMTP-Gmail>

=item * Search CPAN

L<http://search.cpan.org/dist/Email-Send-SMTP-Gmail/>

=back

=cut

