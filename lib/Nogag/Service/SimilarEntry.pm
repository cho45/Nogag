package Nogag::Service::SimilarEntry;

use utf8;
use strict;
use warnings;

use DBI;
use Text::TinySegmenter;
use List::Util qw(reduce);
use Log::Minimal;
use Time::HiRes qw(gettimeofday tv_interval);

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
		$self->recalculate_tfidf_for_all_entries($id);
		$self->recalculate_similar_entry($id);

		my $terms = [
			map {
				$_->{term}
			}
			@{ $self->get_tfidf($id, 1000) }
		];
		$self->r->work_job('Nogag::Worker::RecalculateTFIDF', {
			terms => $terms
		});
	}
}

sub recalculate_tfidf_for_terms {
	my ($self, $terms) = @_;
	infof("recalculate_tfidf_for_terms %s", join(',', @$terms));
	my $dbh = $self->_dbh;
	my $entry_ids = {};
	while (my @part = splice @$terms, 0, 50) {
		my $ph = join(',', ('?') x scalar @part);
		my $results = $dbh->selectall_arrayref(qq{
			SELECT DISTINCT(entry_id) as entry_id FROM tfidf
				WHERE term IN ($ph) AND tfidf > 2.0
		}, { Slice => {} }, @part);
		$entry_ids->{$_->{entry_id}}++ for @$results;
	}
	infof("recalculate_tfidf_for_terms target entry count", scalar keys %$entry_ids);
	$self->recalculate_tfidf_for_all_entries(keys %$entry_ids);
	$self->recalculate_similar_entry(keys %$entry_ids);
}

sub recalculate_tfidf_for_all_entries {
	my ($self, @entry_ids) = @_;
	infof("recalculate_tfidf_for_all_entries %s", scalar @entry_ids);

	my $dbh = $self->_dbh;
	$dbh->sqlite_enable_load_extension(1);
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
			-- tf
			(
				LOG(CAST(term_count AS REAL) + 1) -- term_count in an entry
				/
				(SELECT cnt FROM entry_term_counts WHERE entry_term_counts.entry_id = tfidf.entry_id) -- total term count in an entry
			)
			*
			-- idf
			(1 + LOG(
				(SELECT value FROM entry_total) -- total
				/
				(SELECT cnt FROM term_counts WHERE term_counts.term = tfidf.term) -- term entry count
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

sub recalculate_similar_entry {
	my ($self, @entry_ids) = @_;
	infof('recalculate_similar_entry %d (%s)', scalar @entry_ids, join(',', @entry_ids));
	my $dbh = $self->_dbh;
	$dbh->sqlite_enable_load_extension(1);
	$dbh->do("SELECT load_extension('@{[ config->root->file('assets/libsqlitefunctions.so') ]}')");

	$dbh->prepare_cached(qq{
		CREATE TEMPORARY TABLE similar_candidate_tfidf_sum AS
			SELECT
				entry_id,
				SQRT(SUM(tfidf * tfidf)) AS sum
			FROM
				tfidf
			GROUP BY entry_id
	})->execute();

	my $scores;
	for my $entry_id (@entry_ids) {
		my $t0 = [gettimeofday];
		$dbh->prepare_cached(q{DROP TABLE IF EXISTS similar_candidate})->execute;
		$dbh->prepare_cached(qq{
			CREATE TEMPORARY TABLE similar_candidate AS
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
		})->execute($entry_id - 1000, $entry_id);

		# 正確には full outer join が必要
		# ただし inner join しても分子は変わらない。
		# 分母の要素を別途先に計算しておくことで inner join した結果をもって内積を計算する (ただし集計対象には差がでてしまう)
#use Data::Dumper;
#warn Dumper $dbh->selectall_arrayref(qq{SELECT * FROM similar_candidate_tfidf}, { Slice => {} });

		$scores = $dbh->selectall_arrayref(qq{
				SELECT
					x.entry_id AS eid,
					sum(a_tfidf * b_tfidf) / (max(y.sum) * (select sum from similar_candidate_tfidf_sum where entry_id = ?)) as score
				FROM
					(
						SELECT entry_id, a.tfidf AS a_tfidf, b.tfidf AS b_tfidf FROM (
							(SELECT term, tfidf FROM tfidf WHERE entry_id = ? ORDER BY tfidf DESC LIMIT 100) as a
							INNER JOIN
							(SELECT entry_id, term, tfidf FROM tfidf WHERE entry_id IN (SELECT entry_id FROM similar_candidate)) as b
							ON
							a.term = b.term
						)
					) as x
					LEFT JOIN
					similar_candidate_tfidf_sum as y
					ON y.entry_id = x.entry_id
				WHERE eid != ?
				GROUP BY x.entry_id
				ORDER BY score DESC
				LIMIT 10
		}, { Slice => {} }, $entry_id, $entry_id, $entry_id);
		infof('retrieve score %d, %f', $entry_id, tv_interval($t0));

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
	}

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

	$self->recalculate_similar_entry(map { $_->{id} } @$rows);
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

	$entries;
}

sub get_tfidf {
	my ($self, $entry_id, $limit) = @_;
	$limit ||= 100;
	my $dbh = $self->_dbh;
	$dbh->selectall_arrayref(qq{
		SELECT
			*
		FROM
			tfidf
		WHERE
			entry_id = ?
		ORDER BY tfidf DESC
		LIMIT ?
	}, { Slice => {} }, $entry_id, $limit);
}

sub fill_similar_entries {
	my ($self, $entry) = @_;
	$entry->similar_entries($self->get_similar_entries($entry->id));
}

1;
__END__
