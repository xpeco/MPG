#!/usr/bin/perl
use strict;
use warnings;
use MPG::MPGTwitter;
use Data::Dumper;

my $object=MPGTwitter->new(-debug=>1);

while(1){
   my $statuses;
   eval {
#      my $statuses = $nt->direct_messages({ since_id => 1, count => 3 });
      $statuses = $object->{twitter}->direct_messages(); # last 20
   }; warn "$@\n" if $@;

   if (@$statuses!=0)
   {
	   foreach my $status (reverse @$statuses)
      {
        if ($status->{id} > $object->{lastid})
        {
          print "New direct message\n";
          $object->{lastid}=$status->{id}; # store the last direct_message Id to not repeat
#         $object->_updateLastId();

          print "Tweet nº: $status->{id}\n Created at $status->{created_at}\n By: <$status->{sender}->{screen_name}>\n Content: $status->{text}\n";
          my $data;
          $data->{content}=Dumper($status);
          $data->{message}=$status->{text};
          #$data->{from}=$status->{user}{screen_name};
          $data->{from}=$status->{sender}->{screen_name};

          $object->_insertmessage($data);

          if ($data->{message}=~/$object->{action}->{trigger}/i)
			 {
             my $texto=$object->_action($data->{from});
#				 my $result= eval {$object->{twitter}->new_direct_message($data->{from},$texto)};
             if ($@=~/Parece que ya has dicho eso/)
				 {
						$texto.=' Y que no se repita';
#						$result= eval {$object->{twitter}->new_direct_message($data->{from},$texto)};
	               warn "$@\n" if $@;
				 }
				 else {warn "$@\n" if $@;}
			 }
			 my $destroy=eval {$object->{twitter}->destroy_direct_message($status->{id})}; warn "@\n" if $@;

        }
		  else {print "already read\n";}
      }
   }
print "looping\n";
sleep $object->{frequency};
}

