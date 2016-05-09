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
	ok $e->has_tag('photo');
	ok !$e->has_tag('xxx');
};

subtest image => sub {
	my $e;
	$e = Nogag::Model::Entry->bless({ formatted_body => '<img src="http://foobar">' });
	is $e->image, 'http://foobar';

	$e = Nogag::Model::Entry->bless({ formatted_body => "<img src='http://foobar'>" });
	is $e->image, 'http://foobar';

	$e = Nogag::Model::Entry->bless({ formatted_body => "<img attr src='http://foobar'>" });
	is $e->image, 'http://foobar';

	$e = Nogag::Model::Entry->bless({ formatted_body => '<img src=http://foobar>' });
	is $e->image, 'http://foobar';
};

done_testing;
