package Nogag::Service::SimilarEntry;

use utf8;
use strict;
use warnings;

use DBI;
use Text::TinySegmenter;
use List::Util qw(reduce);
use Log::Minimal;

use Nogag::Config;
use Nogag::Model::Entry;

use parent qw(Nogag::Service);

sub _dbh {
	my ($self) = @_;
	DBI->connect('dbi:SQLite:' . config->param('tfidf_db'), "", "", {
		RaiseError => 1,
		sqlite_see_if_its_a_number => 1,
		sqlite_unicode => 1,
	});
}


sub update {
	my ($self, $entry, %opts) = @_;
	my $id = $entry->{id};
	my $text = lc join("\n", $entry->{title}, $entry->{formatted_body});
	$text =~ s{<style[^<]*?</style>}{}g;
	$text =~ s{<script[^<]*?</script>}{}g;
	$text =~ s{<[^>]+?>}{}g;
	$text =~ s{[^\w]+}{ }g;

	my $words = reduce {
		$a->{$b}++;
		$a;
	} +{},
		map {
			s/^\s|\s$//g;
			$_;
		}
		map {
			if (/[^a-z0-9]/i) {
				Text::TinySegmenter->segment($_);
			} else {
				$_;
			}
		} split /\s/, $text; 

	my $dbh = $self->_dbh;
	$dbh->begin_work;
	$dbh->prepare_cached(q{
		DELETE FROM tfidf WHERE entry_id = ?
	})->execute($id);
	for my $term (keys %$words) {
		if (length $term <= 1) {
			next;
		}

		my $count = $words->{$term};
		$dbh->prepare_cached(q{
			INSERT INTO tfidf
				(`term`, `entry_id`, `term_count`)
			VALUES (?, ?, ?);
		})->execute($term, $id, $count);
	}
	$dbh->commit;
	if (!$opts{skip_recalculate}) {
		$self->recalculate_tfidf_for_terms([ keys %$words ]);
	}
}

sub recalculate_tfidf_for_terms {
	my ($self, $terms) = @_;
	infof("recalculate_tfidf_for_terms %s", $terms);
	my $dbh = $self->_dbh;
	my $entry_ids = {};
	while (my @part = splice @$terms, 0, 50) {
		my $ph = join(',', ('?') x scalar @part);
		my $results = $dbh->selectall_arrayref(qq{
			SELECT DISTINCT(entry_id) as entry_id FROM tfidf WHERE term IN ($ph)
		}, { Slice => {} }, @part);
		$entry_ids->{$_->{entry_id}}++ for @$results;
	}
	$self->recalculate_tfidf_for_all_entries(keys %$entry_ids);
	$self->recalculate_similar_entry($_) for keys %$entry_ids;
}

sub recalculate_tfidf_for_all_entries {
	my ($self, @entry_ids) = @_;
	infof("recalculate_tfidf_for_all_entries %s", scalar @entry_ids);

#	my $sql = q{
#		UPDATE tfidf SET tfidf = 
#			/* tf */
#			(
#				LOG(CAST(term_count AS REAL) + 1) /* term_count in an entry */
#				/
#				LOG(CAST((SELECT SUM(term_count) FROM tfidf as y WHERE y.entry_id = entry_id) AS REAL)) /* total term count in an entry */
#			)
#			*
#			/* idf */
#			(1 + LOG(
#				CAST((SELECT COUNT(DISTINCT entry_id) FROM tfidf) AS REAL) /* total */
#				/
#				CAST((SELECT COUNT(DISTINCT entry_id) FROM tfidf as y WHERE y.term = term) AS REAL) /* term entry count */
#			))
#	};

	my $dbh = $self->_dbh;
	$dbh->func(1, "enable_load_extension");
	$dbh->do("SELECT load_extension('@{[ config->root->file('assets/libsqlitefunctions.so') ]}')");
	$dbh->do(q{
		CREATE TEMPORARY TABLE entry_total AS
			SELECT CAST(COUNT(DISTINCT entry_id) AS REAL) AS value FROM tfidf
	});
	$dbh->do(q{
		CREATE TEMPORARY TABLE term_counts AS
			SELECT term, CAST(COUNT(*) AS REAL) AS cnt FROM tfidf GROUP BY term
	});
	$dbh->do(q{
		CREATE INDEX temp.term_counts_term ON term_counts (term);
	});
	$dbh->do(q{
		CREATE TEMPORARY TABLE entry_term_counts AS
			SELECT entry_id, LOG(CAST(SUM(term_count) AS REAL)) AS cnt FROM tfidf GROUP BY entry_id
	});
	$dbh->do(q{
		CREATE INDEX temp.entry_term_counts_entry_id ON entry_term_counts (entry_id)
	});
	my $sql = q{
		UPDATE tfidf SET tfidf = IFNULL(
			/* tf */
			(
				LOG(CAST(term_count AS REAL) + 1) /* term_count in an entry */
				/
				(SELECT cnt FROM entry_term_counts WHERE entry_term_counts.entry_id = tfidf.entry_id) /* total term count in an entry */
			)
			*
			/* idf */
			(1 + LOG(
				(SELECT value FROM entry_total) /* total */
				/
				(SELECT cnt FROM term_counts WHERE term_counts.term = tfidf.term) /* term entry count */
			))
		, 0.0)
	};
	$dbh->begin_work;
	if (@entry_ids) {
		my $stmt = $dbh->prepare_cached($sql . " WHERE entry_id = ?");
		for my $entry_id (@entry_ids) {
			$stmt->execute($entry_id);
		}
	} else {
		$dbh->prepare_cached($sql)->execute();
	}
	$dbh->commit;
}

#sub search_similar_entry {
#	my ($self, $entry_id) = @_;
#	my $dbh = $self->_dbh;
#	$dbh->func(1, "enable_load_extension");
#	$dbh->do('SELECT load_extension("/tmp/libsqlitefunctions.so")');
#	my $scores = $dbh->selectall_arrayref(qq{
#		SELECT
#			eid,
#			(
#				SELECT
#					SUM(a.tfidf * b.tfidf)
#					/
#					(SQRT(SUM(a.tfidf * a.tfidf)) * SQRT(SUM(b.tfidf * b.tfidf)))
#				FROM
#					(SELECT term, tfidf FROM tfidf WHERE entry_id = ? ORDER BY tfidf DESC LIMIT 1000) as a
#					LEFT JOIN
#					(SELECT term, tfidf FROM tfidf WHERE entry_id = eid) as b
#					ON
#					a.term = b.term
#			) as score,
#			cnt
#		FROM
#			(
#				SELECT entry_id as eid, COUNT(*) as cnt FROM tfidf
#				WHERE term IN (
#					SELECT term FROM tfidf WHERE entry_id = ?
#					ORDER BY tfidf DESC
#					LIMIT 100
#				)
#				GROUP BY entry_id
#			)
#		ORDER BY score DESC
#		LIMIT 30
#	}, { Slice => {} }, $entry_id, $entry_id);
#	use Data::Dumper;
#	warn Dumper $scores ;
#	warn Dumper scalar @$scores ;
#	$scores;
#}

sub recalculate_similar_entry {
	my ($self, $entry_id) = @_;
	infof('recalculate_similar_entry %d', $entry_id);
	my $dbh = $self->_dbh;
	$dbh->sqlite_enable_load_extension(1);
	$dbh->do("SELECT load_extension('@{[ config->root->file('assets/libsqlitefunctions.so') ]}')");

	my $targets = $dbh->selectall_arrayref(qq{
		SELECT
			entry_id,
			cnt
		FROM
			(
				SELECT entry_id, COUNT(*) as cnt FROM tfidf
				WHERE
					entry_id > ? AND
					term IN (
						SELECT term FROM tfidf WHERE entry_id = ?
						ORDER BY tfidf DESC
						LIMIT 100
					)
				GROUP BY entry_id
				HAVING cnt > 5
				ORDER BY cnt DESC
				LIMIT 100
			)
	}, { Slice => {} }, $entry_id - 1000, $entry_id);

	my $scores = [];
	for my $target (@$targets) {
		my $score = $dbh->selectall_arrayref(qq{
			SELECT
				SUM(a_tfidf * b_tfidf)
				/
				(SQRT(SUM(a_tfidf * a_tfidf)) * SQRT(SUM(b_tfidf * b_tfidf)))
				as score
			FROM
				(
					SELECT a.tfidf AS a_tfidf, b.tfidf AS b_tfidf FROM (
						(SELECT term, tfidf FROM tfidf WHERE entry_id = ? ORDER BY tfidf DESC LIMIT 1000) as a
						LEFT JOIN
						(SELECT term, tfidf FROM tfidf WHERE entry_id = ?) as b
						ON
						a.term = b.term
					) UNION
					SELECT a.tfidf AS a_tfidf, b.tfidf AS b_tfidf FROM (
						(SELECT term, tfidf FROM tfidf WHERE entry_id = ? ORDER BY tfidf DESC LIMIT 1000) as b
						LEFT JOIN
						(SELECT term, tfidf FROM tfidf WHERE entry_id = ?) as a
						ON
						a.term = b.term
					)
				)
		}, { Slice => {} }, $entry_id, $target->{entry_id}, $target->{entry_id}, $entry_id)->[0];
		push @$scores, {
			eid => $target->{entry_id},
			score => $score->{score},
			cnt => $target->{cnt},
		};
	}

	$scores = [
		grep { defined && $_->{score} != 1.0 }
		(
			sort { $b->{score} <=> $a->{score} }
			map { $_->{score} //= 0; $_ }
			@$scores
		)[1..10]
	];
	use Data::Dumper;
	warn Dumper $scores ;

	$dbh->begin_work;
	$dbh->prepare_cached(q{
		DELETE FROM related_entries WHERE entry_id = ?
	})->execute($entry_id);
	for my $score (@$scores) {
		$dbh->prepare_cached(q{
			INSERT INTO related_entries (`entry_id`, `related_entry_id`, `score`)
				VALUES (?, ?, ?)
		})->execute($entry_id, $score->{eid}, $score->{score});
	}
	$dbh->commit;

	$scores;
}

sub reimport_all_entries_and_recalculate {
	my ($self) = @_;
	my $rows = 
		$self->r->dbh->select(q{
			SELECT * FROM entries
			ORDER BY `date` DESC, `path` ASC
		});

	for my $row (@$rows) {
		infof("update %s", $row->{date});
		$self->update($row, skip_recalculate => 1);
	}

	$self->recalculate_tfidf_for_all_entries;
	$self->recalculate_similar_entry_for_all_entries;
}

sub recalculate_similar_entry_for_all_entries {
	my ($self) = @_;
	my $rows = 
		$self->r->dbh->select(q{
			SELECT * FROM entries
			ORDER BY `date` DESC, `path` ASC
		});

	for my $row (@$rows) {
		$self->recalculate_similar_entry($row->{id});
	}
}

sub get_similar_entries {
	my ($self, $entry_id) = @_;
	my $dbh = $self->_dbh;
	my $entry_ids = $dbh->selectall_arrayref(qq{
		SELECT
			related_entry_id,
			score
		FROM
			related_entries
		WHERE
			entry_id = ?
		ORDER BY score DESC
		LIMIT 5
	}, { Slice => {} }, $entry_id);

	my $entries = $self->r->dbh->select(q{
		SELECT * FROM entries
		WHERE id IN (:ids)
	}, {
		ids => [
			map {
				$_->{related_entry_id}
			}
			@$entry_ids
		]
	});

	my $score_by_id = reduce {
		$a->{$b->{related_entry_id}} = $b->{score};
		$a;
	} +{}, @$entry_ids;

	Nogag::Model::Entry->bless($_) for @$entries;

	$entries = [
		sort {
			$b->{score} <=> $a->{score};
		}
		map {
			$_->{score} = $score_by_id->{$_->id};
			$_;
		}
		@$entries
	];
	use Data::Dumper;
	warn Dumper $entries ;

	$entries;
}

sub get_tfidf {
	my ($self, $entry_id) = @_;
	my $dbh = $self->_dbh;
	$dbh->selectall_arrayref(qq{
		SELECT
			*
		FROM
			tfidf
		WHERE
			entry_id = ?
		ORDER BY tfidf DESC
		LIMIT 20
	}, { Slice => {} }, $entry_id);
}

sub fill_similar_entries {
	my ($self, $entry) = @_;
	$entry->similar_entries($self->get_similar_entries($entry->id));
}

1;
__END__
