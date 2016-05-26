use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Test::Name::FromLine;

use HTTP::Request::Common;
use HTTP::Message::PSGI;
use Router::Simple;
use JSON;
use List::Util qw(reduce);

use Nogag::Test;
use Nogag;
use Nogag::Model::Entry;

use Nogag::Service::SimilarEntry;

my $postprocess = postprocess(dummy => 1);

my $service = Nogag::Service::SimilarEntry->new(Nogag->new({}));

subtest tfidf => sub {
	my $entries = {
		1 => {
			title => 'foo foo bar baz baz baz',
		},
		2 => {
			title => 'bar baz',
		},
		3 => {
			title => 'foo baz',
		}
	};

	for my $id (keys %$entries) {
		my $entry = $entries->{$id};
		$service->update({
			id => $id,
			title => $entry->{title},
			formatted_body => '',
		}, skip_recalculate => 1);
	}
	$service->recalculate_tfidf_for_all_entries;

	{
		my $by_term = reduce { $a->{$b->{term}} = $b; $a; } +{}, @{ $service->get_tfidf(1) };
		is $by_term->{foo}->{tfidf}, (log(2 + 1) / log(6)) * (1 + log(3 / 2));
		is $by_term->{bar}->{tfidf}, (log(1 + 1) / log(6)) * (1 + log(3 / 2));
		is $by_term->{baz}->{tfidf}, (log(3 + 1) / log(6)) * (1 + log(3 / 3));
	};
	{
		my $by_term = reduce { $a->{$b->{term}} = $b; $a; } +{}, @{ $service->get_tfidf(2) };
		is $by_term->{foo}->{tfidf}, undef;
		is $by_term->{bar}->{tfidf}, (log(1 + 1) / log(2)) * (1 + log(3 / 2));
		is $by_term->{baz}->{tfidf}, (log(1 + 1) / log(2)) * (1 + log(3 / 3));
	};
	{
		my $by_term = reduce { $a->{$b->{term}} = $b; $a; } +{}, @{ $service->get_tfidf(3) };
		is $by_term->{foo}->{tfidf}, (log(1 + 1) / log(2)) * (1 + log(3 / 2));
		is $by_term->{bar}->{tfidf}, undef;
		is $by_term->{baz}->{tfidf}, (log(1 + 1) / log(2)) * (1 + log(3 / 3));
	};
};

done_testing;

