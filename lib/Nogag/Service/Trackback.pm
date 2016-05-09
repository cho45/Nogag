package Nogag::Service::Trackback;

use utf8;
use strict;
use warnings;

use parent qw(Nogag::Service);

use Nogag::Model::Entry;
use Nogag::Service::Cache;

sub retrieve_linking_paths {
	my ($self, $entry) = @_;
	my $paths = [ $entry->formatted_body(1) =~ m{(?:lowreal\.net|debug\.cho45\.stfuawsc\.com)/(\d\d\d\d/\d\d/\d\d/\d+)}g ];
}

sub update_trackbacks {
	my ($self, $entry) = @_;
	my $txn = $self->dbh->txn_scope;

	my $invalid_caches = [];


	# retrieve current linking entries for clearing cache
	my $old_entries = $self->dbh->select(q{
		SELECT entries.* FROM entries INNER JOIN trackbacks ON entries.id = trackbacks.entry_id
		WHERE trackbacks.trackback_entry_id = :entry_id
	}, {
		entry_id => $entry->id
	});
	push @$invalid_caches, @$old_entries;

	# remove current links
	$self->dbh->prepare_cached(q{
		DELETE FROM trackbacks WHERE trackback_entry_id = ?
	})->execute($entry->id);

	# extract new linking entries
	my $paths = $self->retrieve_linking_paths($entry);
	my $entries = $self->dbh->select(q{
		SELECT * FROM entries
		WHERE path IN (:paths)
	}, {
		paths => $paths,
	});
	push @$invalid_caches, @$entries;

	# update
	for my $e (@$entries) {
		$self->dbh->prepare_cached(q{
			INSERT INTO trackbacks (entry_id, trackback_entry_id) VALUES (?, ?);
		})->execute($e->{id}, $entry->id);
	}

	$txn->commit;

	for my $entry (@$invalid_caches) {
		Nogag::Model::Entry->bless($entry);
		Nogag::Service::Cache->invalidate_related($entry->id);
		Nogag::Service::Cache->generate_cache_for_path($entry->path('/'));
	}
}

sub fill_trackbacks {
	my ($self, $entry) = @_;
	my $entries = $self->dbh->select(q{
		SELECT entries.* FROM entries INNER JOIN trackbacks ON entries.id = trackbacks.trackback_entry_id
		WHERE trackbacks.entry_id = :entry_id
	}, {
		entry_id => $entry->id
	});
	Nogag::Model::Entry->bless($_) for @$entries;
	$entry->trackbacks($entries);
	$entry;
}

1;
__END__
