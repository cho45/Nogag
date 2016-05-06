use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Test::Name::FromLine;
use Data::MessagePack;

use Cache::Invalidatable::SQLite;

use File::Temp;

my $temp = File::Temp->new;
close $temp;

my $dbfile = $temp->filename;
my $db = 'dbi:SQLite:' . $dbfile;

subtest 'setup' => sub {
	my $dbh = DBI->connect($db, "", "", {
		sqlite_allow_multiple_statements => 1,
		RaiseError => 1,
		sqlite_see_if_its_a_number => 1,
		sqlite_unicode => 1,
	});

	open my $fh, '<', 'db/cache.sql';
	my $schema = do { local $/; scalar <$fh> };
	close $fh;
	$dbh->do($schema);
	$dbh->disconnect;
	ok 1;
};

my $cache = do {
	my $MessagePack = Data::MessagePack->new;
	$MessagePack->canonical;
	Cache::Invalidatable::SQLite->new(
		db => $dbfile,
		serializer => sub {
			$MessagePack->pack($_[0]);
		},
		deserializer => sub {
			$MessagePack->unpack($_[0]);
		},
	);
};

subtest 'get / remove' => sub {
	$cache->set('cache1', 'foo', []);
	$cache->set('cache2', 'baz', []);

	is($cache->get('cache1'), 'foo');
	is($cache->get('cache2'), 'baz');

	$cache->remove('cache1');
	is($cache->get('cache1'), undef);
	$cache->remove('cache2');
	is($cache->get('cache2'), undef);
};

subtest 'invalidate_related' => sub {
	subtest A => sub {
		$cache->set('cache1', 'foo', ['/']);
		$cache->set('cache2', 'baz', ['/']);
		is($cache->get('cache1'), 'foo');
		is($cache->get('cache2'), 'baz');

		$cache->invalidate_related('/');
		is($cache->get('cache1'), undef);
		is($cache->get('cache2'), undef);
	};

	subtest B => sub {
		$cache->set('cache1', 'foo', ['/']);
		$cache->set('cache2', 'baz', []);
		is($cache->get('cache1'), 'foo');
		is($cache->get('cache2'), 'baz');

		$cache->invalidate_related('/');
		is($cache->get('cache1'), undef);
		is($cache->get('cache2'), 'baz');
	};

	subtest C => sub {
		$cache->set('cache1', 'foo', ['/']);
		$cache->set('cache2', 'baz', ['/']);
		is($cache->get('cache1'), 'foo');
		is($cache->get('cache2'), 'baz');

		$cache->remove('cache1');
		is($cache->get('cache1'), undef);
		is($cache->get('cache2'), 'baz');
	};

	subtest D => sub {
		$cache->set('cache1', 'foo', ['/', 'a']);
		$cache->set('cache2', 'baz', ['/', 'b']);
		is($cache->get('cache1'), 'foo');
		is($cache->get('cache2'), 'baz');

		$cache->invalidate_related('a');
		is($cache->get('cache1'), undef);
		is($cache->get('cache2'), 'baz');

		$cache->invalidate_related('b');
		is($cache->get('cache1'), undef);
		is($cache->get('cache2'), undef);
	};
};

done_testing;
