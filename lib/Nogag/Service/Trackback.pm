package Nogag::Service::Trackback;

use utf8;
use strict;
use warnings;

use parent qw(Nogag::Service);

use Nogag::Model::Entry;
use Nogag::Service::Cache;

sub retrieve_linking_entries {
	my ($self, $entry) = @_;
	my $paths = [ $entry->formatted_body(1) =~ m{(?:lowreal\.net|debug\.cho45\.stfuawsc\.com)/(\d\d\d\d/\d\d/\d\d/\d+)}g ];
	my $entries = $self->dbh->select(q{
		SELECT * FROM entries
		WHERE path IN (:paths)
	}, {
		paths => $paths,
	});
}

sub update_trackbacks {
	my ($self, $old, $new) = @_;

	my $invalid_caches = [];

	push @$invalid_caches, @{ $self->retrieve_linking_entries($old) };

	my $txn = $self->dbh->txn_scope;
	$dbh->prepare_cached(q{
		DELETE FROM trackbacks WHERE trackback_entry_id = ?
	})->execute($old->id);

	my $entries = $self->retrieve_linking_entries($new);
	push @$invalid_caches, @$entries;

	for my $entry (@$entries) {
		$dbh->prepare_cached(q{
			INSERT INTO trackbacks (entry_id, trackback_entry_id) VALUES (?, ?);
		})->execute($entry->id, $new->id);
	}

	$txn->commit;

	for my $entry (@$invalid_caches) {
		Nogag::Service::Cache->invalidate_related($_->id);
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
