package Nogag::Service::SimilarImage;

use utf8;
use strict;
use warnings;

use parent qw(Nogag::Service);

use HTTP::Request::Common;
use Term::ProgressBar;
use Log::Minimal;
use Path::Class;
use LWP::UserAgent;
use Digest::SHA1 qw(sha1_hex);
use Image::Libpuzzle;

use Nogag::Config;
use Nogag::Model::Entry;


my $imgcache = dir(config->param("imgcache_root")) or die "imgcache_root is not set";
my $ua = LWP::UserAgent->new;

sub transform_url {
	my ($self, $url) = @_;
	if ($url =~ /googleusercontent|ggpht/) {
		# XXX reduce size
		$url =~ s{/s2048/}{/s500/};
	}
	$url;
}

sub download {
	my ($self, $url, %opts) = @_;
	$url = $self->transform_url($url);
	my $hash = sha1_hex($url);

	my $path = $imgcache->file(substr($hash, 0, 2), substr($hash, 2, 2), $hash);
	if (-e $path) {
		infof("already downloaded %s <- %s", $path, $url);
		return $path;
	} else {
		infof("downloading... %s <- %s", $path, $url);
		$path->parent->mkpath;
		my $fh = $path->openw;
		my $term;
		my $res = $ua->request( HTTP::Request->new( GET => $url ), sub {
			my ($data, $res, $proto) = @_;
			unless ($term) {
				if ($opts{progress}) {
					$term = Term::ProgressBar->new( $res->header('Content-Length') );
				}
			}
			if ($term) {
				$term->update( $term->last_update + length $data );
			}
			print $fh $data;
		});
		close $fh;
		unless ($res->is_success) {
			$path->remove;
		}
		return $path;
	}
}

sub process_all_photo_entries {
	my ($self, $sub) = @_;

	my $rows =
		$self->r->dbh->select(q{
			SELECT * FROM entries
			WHERE title LIKE :query
			ORDER BY id
		}, {
			query => '%[photo]%'
		});


	for my $row (@$rows) {
		infof("Processing %s", $row->{path});
		Nogag::Model::Entry->bless($row);
		$sub->($row);
	}
}

sub index {
	my ($self, $entry) = @_;
	my $dbh = $self->r->images_dbh;
	my $txn = $dbh->txn_scope;
	$dbh->update(q{
		DELETE FROM images WHERE entry_id = :entry_id
	}, { entry_id => $entry->id });
	for my $url (@{ $entry->images }) {
		my $path = $self->download($url);
		my $p = Image::Libpuzzle->new;
		my $sig = eval { $p->fill_cvec_from_file($path) } or do {
			warnf("failed to fill cvec %s : %s", $path, $@);
			next;
		};
		$dbh->update(q{
			INSERT OR REPLACE INTO images
				(
					`uri`,
					`entry_id`,
					`sig`
				)
			VALUES
				(
					:uri,
					:entry_id,
					:sig
				)
		}, {
			uri => $url,
			entry_id => $entry->id,
			sig => $sig,
		});

		my $id = $dbh->value(q{
			SELECT id FROM images WHERE uri = :uri
		}, { uri => $url });

		$dbh->update(q{
			DELETE FROM ngram WHERE image_id = :id
		}, { id => $id });

		my $pos = 0;
		for my $ngram (@{ $p->signature_as_hex_ngrams(10) }) {
			my $word = pack("nH*", $pos++, $ngram);
			$dbh->update(q{
				INSERT INTO ngram
					(
						`image_id`,
						`word`
					)
				VALUES
					(
						:id,
						:word
					)
			}, {
				id => $id,
				word => $word,
			});
			$pos++;
		}
	}
	$txn->commit;
}

sub similar_photos {
	my ($self, $url, %opts) = @_;
	my $id = $self->r->images_dbh->value(q{
		SELECT id FROM images WHERE uri = :uri
	}, { uri => $url });
	unless ($id) {
		warnf("unindexed photo: %s", $url);
		return [];
	}
	$self->similar_photos_by_id($id);
}

sub get_similar_photos_by_entry_id {
	my ($self, $entry_id, %opts) = @_;
	my $ids = $self->r->images_dbh->select(q{
		SELECT id FROM images WHERE entry_id = :entry_id
	}, { entry_id => $entry_id });
	my $res = [];
	for my $id (@$ids) {
		# マージしてしまう
		push @$res, @{ $self->similar_photos_by_id($id->{id}, %opts) };
	}
	[ (sort {
		$b->{score} <=> $a->{score}
	} @$res)[0..($opts{limit}-1)] ];
}

sub similar_photos_by_id {
	my ($self, $id, %opts) = @_;
	my $res = $self->r->images_dbh->select(q{
		SELECT
			i.uri,
			i.entry_id,
			COUNT(isw.word) as score
		FROM
			images AS i
				JOIN ngram AS isw ON i.id = isw.image_id
				JOIN ngram AS isw_search ON isw.word = isw_search.word AND isw.image_id != isw_search.image_id
		WHERE
				isw_search.image_id = :id
		GROUP BY i.id, i.uri, i.sig
		ORDER BY score DESC
		LIMIT :limit
	}, { id => $id, limit => $opts{limit} || 10 });
}

1;
__END__
