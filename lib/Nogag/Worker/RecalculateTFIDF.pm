package Nogag::Worker::RecalculateTFIDF;

use utf8;
use strict;
use warnings;

use Nogag;

use parent qw(TheSchwartz::Worker);
use Nogag::Service::SimilarEntry;

sub work {
	my $class = shift;
	my TheSchwartz::Job $job = shift;

	my $terms = $job->arg->{terms};

	my $r = Nogag->new({});
	$r->service('Nogag::Service::SimilarEntry')->recalculate_tfidf_for_terms($terms);

	$job->completed;
}


1;
__END__
