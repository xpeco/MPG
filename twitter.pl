#!/usr/bin/perl
use strict;
use warnings;
use MPG::MPGTwitter;
use Data::Dumper;

my $object=MPGTwitter->new(-debug=>1);

while(1){
   my $statuses;
   eval { $statuses = $object->{twitter}->direct_messages(); };

   if($@)
   {
     print "Error from Twitter Server: $@\n";
     print "Don't worry, we will try to reconnect soon\n";
   }
   else{
        print "Read if something...\n";
        if ($statuses!=0)
        {
           foreach my $status (reverse @$statuses)
           {
              if ($status->{id} > $object->{lastid})
              {
                 print "New direct message\n";
                 $object->{lastid}=$status->{id}; # store the last direct_message Id to avoid repeating
                 $object->updateLastId();

                 print "Tweet nº: $status->{id}\n Created at $status->{created_at}\n By: <$status->{sender}->{screen_name}>\n Content: $status->{text}\n";
                 my $data;
                 $data->{content}=Dumper($status);
                 $data->{message}=$status->{text};
                 #$data->{from}=$status->{user}{screen_name};
                 $data->{from}=$status->{sender}->{screen_name};

                 $object->_insertmessage($data);

                 if ($data->{message}=~/$object->{action}->{trigger}/i)
                 {
                    my $m;
                    $m->{text}=$object->_action($data->{from});
                    $m->{screen_name}=$data->{from};

                    my $result= eval {$object->{twitter}->new_direct_message($m)};
                    if ($@=~/Parece que ya has dicho eso/)
                    {
                       $m->{text}.=' (Cuidado, ya has pedido tu saldo hace un momento)';
                       $result= eval {$object->{twitter}->new_direct_message($m)};
                       warn "$@\n" if $@;
                    }
                    else {warn "$@\n" if $@;}
                 }
                 # my $destroy=eval {$object->{twitter}->destroy_direct_message($status->{id})}; warn "@\n" if $@;

              }
              else {print "already read\n";}
           }
        } # if message
   }
print "looping\n";
sleep $object->{frequency};
$object->ping();
}

