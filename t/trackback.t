use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Test::Name::FromLine;

use HTTP::Request::Common;
use HTTP::Message::PSGI;
use Router::Simple;
use JSON;

use Nogag::Test;
use Nogag;
use Nogag::Model::Entry;

use Nogag::Service::Trackback;

my $postprocess = postprocess(dummy => 1);

my $service = Nogag::Service::Trackback->new(Nogag->new({}));

subtest 'lowreal.net' => sub {
	{
		my $paths = $service->retrieve_linking_paths(Nogag::Model::Entry->bless({
			formatted_body => 'https://lowreal.net/2016/06/01/1',
		}));
		is_deeply $paths, [ '2016/06/01/1' ];
	};
	{
		my $paths = $service->retrieve_linking_paths(Nogag::Model::Entry->bless({
			formatted_body =>
				'https://lowreal.net/2016/06/01/1 https://lowreal.net/2016/06/01/2 ',
		}));
		is_deeply $paths, [ '2016/06/01/1', '2016/06/01/2' ];
	};
};

subtest 'debug.cho45' => sub {
	{
		my $paths = $service->retrieve_linking_paths(Nogag::Model::Entry->bless({
			formatted_body => 'https://debug.cho45.stfuawsc.com/2016/06/01/1',
		}));
		is_deeply $paths, [ '2016/06/01/1' ];
	};
};

done_testing;
