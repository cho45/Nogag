package Nogag::Worker::PostEntry;

use utf8;
use strict;
use warnings;

use Nogag;

use parent qw(TheSchwartz::Worker);

sub work {
	my $class = shift;
	my TheSchwartz::Job $job = shift;

	my $entry = $job->arg->{entry};
	my $invalidate_target = $job->arg->{invalidate_target};

	my $r = Nogag->new({});
	$r->service('Nogag::Service::Trackback')->update_trackbacks($entry);
	Nogag::Service::Cache->invalidate_related($invalidate_target);
	Nogag::Service::Cache->generate_cache_for_path($entry->path('/'));
	Nogag::Service::Cache->generate_cache_for_path('/');

	$r->service('Nogag::Service::SimilarEntry')->update($entry);

	$job->completed;
}


1;
__END__
