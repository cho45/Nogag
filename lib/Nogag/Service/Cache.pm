package Nogag::Service::Cache;

use utf8;
use strict;
use warnings;

use Data::MessagePack;
use HTTP::Message::PSGI;
use HTTP::Request::Common;

use Cache::Invalidatable::SQLite;
use Nogag::Config;

use parent qw(Nogag::Service);

my $cache = do {
	my $MessagePack = Data::MessagePack->new;
	$MessagePack->canonical;
	$MessagePack->utf8(0);
	Cache::Invalidatable::SQLite->new(
		db => config->param('cache_db'),
		serializer => sub {
			$MessagePack->pack(shift);
		},
		deserializer => sub {
			$MessagePack->unpack(shift);
		},
	);
};

sub __cache {
	$cache;
}

sub invalidate_related {
	$cache->invalidate_related($_[1]);
}

sub get {
	$cache->get($_[1]);
}

sub set {
	$cache->set($_[1], $_[2], $_[3]);
}

sub generate_cache_for_path {
	my ($class, $path) = @_;
	require Nogag;
	my $res = Nogag->new(GET($path, 'Cache-Control' => 'no-cache')->to_psgi)->run->res;
}

1;
__END__
