package Nogag::Worker::PostEntry;

use utf8;
use strict;
use warnings;

use Nogag;
use Nogag::Service::Trackback;
use Nogag::Service::Cache;

use parent qw(TheSchwartz::Worker);

sub work {
	my $class = shift;
	my TheSchwartz::Job $job = shift;

	my $entry = $job->arg->{entry};
	my $invalidate_target = $job->arg->{invalidate_target};

	my $r = Nogag->new({});
	$r->service('Nogag::Service::Trackback')->update_trackbacks($entry);
	$r->service('Nogag::Service::Cache')->invalidate_related($invalidate_target);
	$r->service('Nogag::Service::Cache')->generate_cache_for_path($entry->path('/'));
	$r->service('Nogag::Service::Cache')->generate_cache_for_path('/');
	for my $tag (@{ $entry->tags }) {
		$r->service('Nogag::Service::Cache')->generate_cache_for_path('/'.$tag.'/');
	}
	$r->service('Nogag::Service::SimilarImage')->index($entry);

	$job->completed;
}


1;
__END__
