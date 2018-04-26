use strict;
use warnings;
use lib 't/lib';

use Test::Time;
use Test::More;
use Test::Name::FromLine;
use Nogag::Test;

use HTTP::Request::Common;
use HTTP::Message::PSGI;
use Router::Simple;
use JSON;
use Time::Seconds;

use Nogag;
use Nogag::Time;
use Nogag::Service::Entry;

#my $service = Nogag::Service::Entry->new(Nogag->new({}));
#
#my $entry = $service->create_new_entry(
#	title => 'foo',
#	body => 'bar',
#);
#
#use Data::Dumper;
#warn Dumper $entry ;

ok 1;

done_testing;
