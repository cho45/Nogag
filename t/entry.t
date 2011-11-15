use v5.14;

use Test::More;

use Nogag::Model::Entry;

subtest tags => sub {
	my $e;

	$e = Nogag::Model::Entry->bless({ title => 'foobar' });
	is_deeply $e->tags, [];

	$e = Nogag::Model::Entry->bless({ title => '[photo]' });
	is_deeply $e->tags, ['photo'];

	$e = Nogag::Model::Entry->bless({ title => '[photo][foo]' });
	is_deeply $e->tags, ['photo', 'foo'];
};

done_testing;
