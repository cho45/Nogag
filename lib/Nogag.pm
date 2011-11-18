package Nogag;

use utf8;
use strict;
use warnings;

use Encode;

use Nogag::Base;
use Nogag::Time;
use Nogag::Model::Entry;

use Time::Seconds;

use parent qw(Nogag::Base);

our @EXPORT = qw(config throw);

route "/login" => sub {
	my ($r) = @_;

	if ($r->req->method eq 'POST') {
		if ($r->req->param('password') eq config->param('password')) {
			$r->session->set('auth' => 1);
			throw code => 302, location => '/';
		} else {
			$r->stash('error' => 'Invalid Password');
		}
	}

	$r->html('login.html');
};

route "/api/edit" => sub {
	my ($r) = @_;
	return $r->json({ error => 'require authentication' }) unless $r->has_auth;

	$r->json(+{
		foo => 'bar'
	});
};


route "/" => sub {
	my ($r) = @_;

	my $page = $r->req->number_param('page') || 1;

	my $entries;

	if (my $query = $r->req->string_param('query')) {
		$entries = $r->dbh->select(q{
			SELECT * FROM entries
			WHERE title LIKE :query OR formatted_body LIKE :query
			ORDER BY `date` DESC, `path` ASC
			LIMIT :limit OFFSET :offset
		}, {
			query  => "%$query%",
			limit  => config->param('entry_per_page'),
			offset => ($page - 1) * config->param('entry_per_page'),
		});
	} else {
		$entries = $r->dbh->select(q{
			SELECT * FROM entries
			ORDER BY `date` DESC, `path` ASC
			LIMIT :limit OFFSET :offset
		}, {
			limit  => config->param('entry_per_page'),
			offset => ($page - 1) * config->param('entry_per_page'),
		});
	}

	Nogag::Model::Entry->bless($_) for @$entries;

	my $count = $r->dbh->value('SELECT count(*) FROM entries');

	$r->stash(entries => $entries);
	$r->stash(count => $count);
	$r->stash(page => $page);

	$r->html('index.html');
};

my $archive = sub {
	my ($r) = @_;
	my $year  = $r->req->param('year');
	my $month = $r->req->param('month');
	my $day   = $r->req->param('day');

	my $start = Nogag::Time->gmtime([
		0, 0, 0,
		defined $day   ? $day         : 1,
		defined $month ? $month - 1   : 1,
		$year - 1900,
		undef, undef, undef
	]);

	my $end   = defined $day   ? $start + ONE_DAY:
	            defined $month ? $start->add_months(1):
	            $start->add_years(1);

	my $entries = $r->dbh->select(q{
		SELECT * FROM entries
		WHERE :start <= date AND date < :end
		ORDER BY path
	}, {
		start => $start->strftime("%Y-%m-%d"),
		end   => $end->strftime("%Y-%m-%d"),
	});

	Nogag::Model::Entry->bless($_) for @$entries;

	$r->stash(entries => $entries);

	$r->html('index.html');
};

# route '/{year:[0-9]{4}}/' => $archive;
route '/{year:[0-9]{4}}/{month:[0-9]{2}}/' => $archive;
route '/{year:[0-9]{4}}/{month:[0-9]{2}}/{day:[0-9]{2}}/' => $archive;

route '/archive' => sub {
	my ($r) = @_;

	my $dates = $r->dbh->select(q{
		SELECT
			strftime('%Y', date) as year,
			strftime('%Y-%m', date) as date,
			count(*) as count
		FROM entries
		GROUP BY strftime('%Y-%m', date)
		ORDER BY date
	});

	my %dates = map { $_->{date} => $_->{count} } @$dates;

	my $years = [];
	for my $year ($dates->[0]->{year} .. $dates->[-1]->{year}) {
		my $months = [];
		for my $month (1..12) {
			push @$months, +{
				link  => sprintf("/%04d/%02d/", $year, $month),
				month => $month,
				count => $dates{sprintf("%04d-%02d", $year, $month)} || 0,
			};
		}
		push @$years, +{
			year   => $year,
			months => $months,
		};
	}

	$r->stash(archive => $years);
	$r->html('index.html');
};

route '/{path:.+}' => sub {
	my ($r) = @_;

	my $path = $r->req->param('path');

	my $is_category = ($path =~ m{/$});

	if ($is_category) {
		my $page = $r->req->number_param('page') || 1;
		$path =~ s{/}{}g;

		my $entries = $r->dbh->select(q{
			SELECT * FROM entries
			WHERE title LIKE :query OR formatted_body LIKE :query
			ORDER BY `date` DESC, `path` ASC
			LIMIT :limit OFFSET :offset
		}, {
			query  => "%[$path]%",
			limit  => config->param('entry_per_page'),
			offset => ($page - 1) * config->param('entry_per_page'),
		});

		Nogag::Model::Entry->bless($_) for @$entries;

		my $count = $r->dbh->value('SELECT count(*) FROM entries');

		$r->stash(entries => $entries);
		$r->stash(count => $count);
		$r->stash(page => $page);
	} else {
		my $entry = $r->dbh->select(q{
			SELECT * FROM entries
			WHERE path = :path
		}, {
			path => $path,
		})->[0] or throw code => 404, message => 'Not Found';

		my $old_entry = $r->dbh->select(q{
			SELECT * FROM entries
			WHERE created_at < :created_at
			ORDER BY created_at DESC
			LIMIT 1
		}, {
			created_at => $entry->{created_at}
		})->[0];

		my $new_entry = $r->dbh->select(q{
			SELECT * FROM entries
			WHERE created_at > :created_at
			ORDER BY created_at ASC
			LIMIT 1
		}, {
			created_at => $entry->{created_at}
		})->[0];

		Nogag::Model::Entry->bless($entry);

		$r->stash(entries => [ $entry ]);
		$r->stash(entry => $entry);
		$r->stash(old_entry => $old_entry);
		$r->stash(new_entry => $new_entry);
		$r->stash(title => $entry->{title} || $entry->created_at->offset(9)->strftime("%H:%M/%Y-%m-%d") );
	}

	$r->html('index.html');
};

1;
