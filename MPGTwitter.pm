package MPGTwitter;

use strict;
use warnings;
use vars qw($VERSION);

$VERSION='0.1';

use Net::Twitter::Lite;
use DBI;
use XML::Simple;

sub new{
       my $class=shift;
       my $self={@_};
       bless($self,$class);
       $self->_initxml;
       $self->_initdb;
       $self->_initdbaction;
       $self->_inittwitter;
       return $self;
}
sub _initxml{
       my $self=shift;
       $self->{xml}=XMLin('./config.xml');
		 return;
}

sub _initdb{
       my $self=shift;
       $self->{db}=DBI->connect("DBI:mysql:$self->{xml}->{database}:$self->{xml}->{host}",
       $self->{xml}->{user},
       $self->{xml}->{password});
       
       if (not $self->{db}){
         print STDERR "Connection to DB failed :-(\n";
         exit(0);
       }
}

sub _initdbaction{
		 my $self=shift;
       my $do=$self->{db}->prepare("select * from TwitterAction where Status='Enabled'");
       $do->execute;
       my $records=$do->fetchall_arrayref({});

		 $self->{dbaction}=DBI->connect("DBI:mysql:$records->[0]->{SQL_Table}:$records->[0]->{SQL_Host}",$records->[0]->{SQL_User},$records->[0]->{SQL_Pass});
		 $self->{action}->{query}=$records->[0]->{SQL_Query};
		 $self->{action}->{answer}=$records->[0]->{SQL_Answer};
		 $self->{action}->{trigger}=$records->[0]->{Trigger};

       if (not $self->{dbaction}){
         print STDERR "Connection to DB TwitterAction failed :-(\n";
         exit(0);
       }
}



sub _inittwitter{
       my $self=shift;
       my $do=$self->{db}->prepare("select * from TwitterConfig where Status='Enabled'");
       $do->execute;
       my $records=$do->fetchall_arrayref({});
       $self->{account}=$records->[0]->{ACCOUNT}; 
       $self->{password}=$records->[0]->{PASSWORD};
       $self->{frequency}=$records->[0]->{Frequency}; 
       $self->{lastid}=$records->[0]->{LastID}; 
       $self->{idreg}=$records->[0]->{Id}; 

		 $self->{twitter} = Net::Twitter::Lite->new(
    			consumer_key        => $records->[0]->{consumer_key},
			   consumer_secret     => $records->[0]->{consumer_secret},
				access_token        => $records->[0]->{access_token},
				access_token_secret => $records->[0]->{access_token_secret}
		 );
}

sub updateLastId{
		my $self=shift;
      my $do=$self->{db}->prepare("update TwitterConfig set LastID=\'$self->{lastid}\' where Id=\'$self->{idreg}\'");
      $do->execute;
}

sub _insertmessage{
		my $self=shift;
      my $data=shift;
      my $do=$self->{db}->prepare("insert into TwitterMessages (`From`,`Message`) VALUES (\'$data->{from}\',\'$data->{message}\');");
      $do->execute;
		return 1;
}

sub _action{
       my $self=shift;
       my $user=shift;
		 my $var='desconocido';
       my $query=$self->{action}->{query};
       $query=~s/_USER_/\'$user\'/;
       my $do=$self->{dbaction}->prepare($query);
       $do->execute;
       my $records=$do->fetchall_arrayref({});
		 if(@$records!=0){
       	$var=$records->[0]->{VAR};
		 }
       my $string=$self->{action}->{answer};
       $string=~s/_VAR_/$var/g;

		 return $string;
}

1;

