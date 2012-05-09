package Nogag;

use v5.14;
use utf8;
use strict;
use warnings;

use Encode;
use Time::Seconds;
use HTML::Trim;
use URI::QueryParam;
use Digest::MD5 qw(md5_hex);

use Nogag::Base;
use Nogag::Time;
use Nogag::Model::Entry;

use Nogag::Formatter::Hatena;

use parent qw(Nogag::Base);

our @EXPORT = qw(config throw);

route "/" => \&index;
route "/login" => \&login;
route "/api/edit" => \&edit;
route "/sitemap.xml" => \&sitemap;
route "/mobilesitemap.xml" => \&mobilesitemap;
route "/feed" => \&feed;
route "/robots.txt" => \&robots_txt;
route "/api/kousei" => "Nogag::API kousei";
route "/test" => \&test;

# route '/{year:[0-9]{4}}/' => \&archive;
route '/{year:[0-9]{4}}/{month:[0-9]{2}}/' => \&archive;
route '/{year:[0-9]{4}}/{month:[0-9]{2}}/{day:[0-9]{2}}/' => \&archive;
route '/archive' => \&archive_index;
route '/{path:.+}' => \&permalink;

sub login {
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
}

sub edit {
	my ($r) = @_;
	return $r->json({ error => 'require authentication' }) unless $r->has_auth;

	my $entry;
	if (my $id = $r->req->param('id')) {
		$entry = $r->dbh->select(q{
			SELECT * FROM entries
			WHERE id = :id
		}, {
			id => $id
		})->[0];
	} else {
		$entry = {
		};
	}

	Nogag::Model::Entry->bless($entry);

	$r->stash(entry => $entry);

	given ($r->req->method) {
		when ('GET') {
			$r->json(+{
				html => $r->render('form.html'),
			});
		}

		when ('POST') {
			my $formatter = "Nogag::Formatter::" . ($entry->format || 'Hatena');
			$formatter->use or die $@;

			if ($entry->id) {
				$entry->{body} = $r->req->string_param('body');

				$r->dbh->update(q{
					UPDATE entries
					SET
						title = :title,
						body = :body,
						modified_at = :modified_at,
						formatted_body = :formatted_body
					WHERE
						id = :id
				}, {
					id             => $entry->id,
					title          => $r->req->string_param('title'),
					body           => $r->req->string_param('body'),
					formatted_body => $formatter->format($entry),
					modified_at    => gmtime.q(),
				})
			} else {
				my $date = localtime;
				my $now  = gmtime;
				my $count = $r->dbh->select('SELECT count(*) FROM entries WHERE `date` = ?', { date => $date->strftime('%Y-%m-%d') })->[0]->{'count(*)'};
				my $path  = $date->strftime('%Y/%m/%d/') . ($count + 1);

				$entry->{path} = $path;
				$entry->{body} = $r->req->string_param('body');

				$r->dbh->update(q{
					INSERT INTO entries
						(
							`title`,
							`body`,
							`formatted_body`,
							`path`,
							`format`,
							`date`,
							`created_at`,
							`modified_at`
						)
						VALUES
						(
							:title,
							:body,
							:formatted_body,
							:path,
							:format,
							:date,
							:created_at,
							:modified_at
						)
				}, {
					title          => $r->req->string_param('title'),
					body           => $r->req->string_param('body'),
					formatted_body => Nogag::Formatter::Hatena->format($entry),
					path           => $path,
					format         => 'Hatena',
					date           => $date->strftime('%Y-%m-%d'),
					created_at     => $now,
					modified_at    => $now,
				});

				$entry->{id} = $r->dbh->sqlite_last_insert_rowid;
			}

			$entry = $r->dbh->select(q{
				SELECT * FROM entries
				WHERE id = :id
			}, {
				id => $entry->id
			})->[0];

			Nogag::Model::Entry->bless($entry);

			# $r->res->redirect("/" . $entry->path);
			$r->res->redirect(scalar $r->req->param('location'));
		}

		default {
			$r->json(+{
				error => 'Invalid request method'
			});
		}
	}
}

sub index {
	my ($r) = @_;

	my $page = $r->req->number_param('page', 100) || 1;

	my $entries;

	if ($r->has_auth && (my $query = $r->req->string_param('query'))) {
		$entries = $r->dbh->select(q{
			SELECT * FROM entries
			WHERE title LIKE :query OR formatted_body LIKE :query
			ORDER BY `date` DESC, `created_at` ASC
			LIMIT :limit OFFSET :offset
		}, {
			query  => "%$query%",
			limit  => config->param('entry_per_page'),
			offset => ($page - 1) * config->param('entry_per_page'),
		});
	} else {
		my $dates = $r->dbh->select(q{
			SELECT `date` FROM entries
			GROUP BY `date`
			ORDER BY `date` DESC
			LIMIT :limit OFFSET :offset
		}, {
			limit  => config->param('entry_per_page'),
			offset => ($page - 1) * config->param('entry_per_page'),
		});

		$entries = $r->dbh->select(q{
			SELECT * FROM entries
			WHERE `date` IN (:dates)
			ORDER BY `date` DESC, `created_at` ASC
		}, {
			dates => [ map { $_->{date} } @$dates ]
		});
	}

	Nogag::Model::Entry->bless($_) for @$entries;

	my $count = $r->dbh->value('SELECT count(*) FROM entries');

	@$entries or $r->res->status(404);

	if (@$entries) {
		my $modified_at = [ sort { $b->modified_at <=> $a->modified_at } @$entries]->[0]->modified_at;
		my $etag = md5_hex(join("\n", $modified_at->epoch, -s $r->config->root->file('templates/index.html')));
		$r->req->if_none_match($etag) or throw code => 304, message => 'Not Modified';
		$r->res->header('ETag' => $etag);
		$r->res->header('Last-Modified' => $modified_at->strftime('%a, %d %b %Y %H:%M:%S GMT'));
	}

	$r->stash(entries => $entries);
	$r->stash(count => $count);
	$r->stash(next_page => do {
		if ($page < 100 && @$entries) {
			my $uri = $r->req->uri->clone;
			$uri->query_param_delete('page');
			$uri->query_param_append('page' => $page + 1);
			$uri->path_query;
		}
	});

	$r->html('index.html');
}

sub archive {
	my ($r) = @_;

	my $year  = $r->req->param('year');
	my $month = $r->req->param('month');
	my $day   = $r->req->param('day');

	# return throw code => 403, message => 'Too old entries' if $year < localtime->year - 2 && !$r->has_auth;

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
		ORDER BY created_at
	}, {
		start => $start->strftime("%Y-%m-%d"),
		end   => $end->strftime("%Y-%m-%d"),
	});

	Nogag::Model::Entry->bless($_) for @$entries;

	if (@$entries) {
		my $modified_at = [ sort { $b->modified_at <=> $a->modified_at } @$entries]->[0]->modified_at;
		my $etag = md5_hex(join("\n", $modified_at->epoch, -s $r->config->root->file('templates/index.html')));
		$r->req->if_none_match($etag) or throw code => 304, message => 'Not Modified';
		$r->res->header('ETag' => $etag);
		$r->res->header('Last-Modified' => $modified_at->strftime('%a, %d %b %Y %H:%M:%S GMT'));
	}

	my $title = defined $day   ? sprintf('%d年%d月%d日の日記', $year, $month, $day):
	            defined $month ? sprintf('%d年%d月の日記', $year, $month):
	            sprintf('%d年の日記', $year);

	$r->stash(year => $year);
	$r->stash(month => $month);
	$r->stash(day => $day);
	$r->stash(title => $title);
	$r->stash(entries => $entries);

	$r->html('index.html');
};

sub archive_index {
	my ($r, %opts) = @_;

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

	$r->stash(title => 'アーカイブ');
	$r->stash(archive => [ reverse @$years ]);
	$r->html('index.html') unless $opts{stash};
}

sub permalink {
	my ($r) = @_;

	my $path = $r->req->param('path');

	my $is_category = ($path =~ m{^([^/]+)/$});

	if ($is_category) {
		my $name = $1;

		my $page = $r->req->number_param('page', 100) || 1;

		my $entries = $r->dbh->select(q{
			SELECT * FROM entries
			WHERE title LIKE :query
			ORDER BY `date` DESC, `created_at` ASC
			LIMIT :limit OFFSET :offset
		}, {
			query  => "%[$name]%",
			limit  => config->param('entry_per_page'),
			offset => ($page - 1) * config->param('entry_per_page'),
		});

		Nogag::Model::Entry->bless($_) for @$entries;

		my $count = $r->dbh->value('SELECT count(*) FROM entries');

		@$entries or $r->res->status(404);

		if (@$entries) {
			my $modified_at = [ sort { $b->modified_at <=> $a->modified_at } @$entries]->[0]->modified_at;
			my $etag = md5_hex(join("\n", $modified_at->epoch, -s $r->config->root->file('templates/index.html')));
			$r->req->if_none_match($etag) or throw code => 304, message => 'Not Modified';
			$r->res->header('ETag' => $etag);
			$r->res->header('Last-Modified' => $modified_at->strftime('%a, %d %b %Y %H:%M:%S GMT'));
		}

		$r->stash(category => $name);
		$r->stash(title => sprintf('%s カテゴリー', ucfirst $name));
		$r->stash(entries => $entries);
		$r->stash(count => $count);
		$r->stash(next_page => do {
			if ($page < 100 && @$entries) {
				my $uri = $r->req->uri->clone;
				$uri->query_param_delete('page');
				$uri->query_param_append('page' => $page + 1);
				$uri->path_query;
			}
		});

		my $tmpl = config->root->subdir('templates/category')->file("$name.html");
		if (-e $tmpl) {
			return $r->html($tmpl);
		}
	} else {
		my $entry = $r->dbh->select(q{
			SELECT * FROM entries
			WHERE path = :path
		}, {
			path => $path,
		})->[0] or throw code => 404, message => 'Not Found';

		Nogag::Model::Entry->bless($entry);

		my $etag = md5_hex(join("\n", $entry->modified_at->epoch, -s $r->config->root->file('templates/index.html')));
		$r->req->if_none_match($etag) or throw code => 304, message => 'Not Modified';
		$r->res->header('ETag' => $etag);

		$r->res->header('Last-Modified' => $entry->modified_at->strftime('%a, %d %b %Y %H:%M:%S GMT'));

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

		$r->stash(entries => [ $entry ]);
		$r->stash(entry => $entry);
		$r->stash(permalink => 1);
		$r->stash(old_entry => $old_entry);
		$r->stash(new_entry => $new_entry);
		$r->stash(title => do {
			my $title = $entry->{title} || HTML::Trim::vtrim($entry->formatted_body, 50, '…');
			$title =~ s/<[^>]+>//g;
			$title =~ s{^\s+|\s+$}{}g;
			$title;
		} . $entry->date->strftime(" | %a, %b %e. %Y"));
	}

	$r->html('index.html');
}

sub sitemap {
	my ($r) = @_;

	my $entries = $r->dbh->select(q{
		SELECT path, strftime('%Y-%m-%dT%H:%M:%SZ', modified_at) as lastmod FROM entries ORDER BY `date` DESC
	});

	$r->stash(entries => $entries);
	archive_index($r, stash => 1);
	$r->res->content_type('application/xml; charset=utf-8');
	$r->res->content(encode_utf8 $r->render('sitemap.xml'));
}

sub mobilesitemap {
	my ($r) = @_;

	my $entries = $r->dbh->select(q{
		SELECT path, strftime('%Y-%m-%dT%H:%M:%SZ', modified_at) as lastmod FROM entries ORDER BY `date` DESC
	});

	$r->stash(entries => $entries);
	$r->stash(mobile => 1);
	archive_index($r, stash => 1);
	$r->res->content_type('application/xml; charset=utf-8');
	$r->res->content(encode_utf8 $r->render('mobilesitemap.xml'));
}


sub feed {
	my ($r) = @_;

	my $entries = $r->dbh->select(q{
		SELECT * FROM entries
		WHERE
			title LIKE "%[photo]%" OR
			title LIKE "%[tech]%" OR
			formatted_body LIKE "%nuso-22%"
		ORDER BY `date` DESC, `created_at` ASC
		LIMIT :limit
	}, {
		limit => 50,
	});

	Nogag::Model::Entry->bless($_) for @$entries;

	$r->stash(entries => $entries);
	$r->res->content_type('application/atom+xml; charset=utf-8');
	$r->res->content(encode_utf8 $r->render('feed.xml'));
}

sub robots_txt {
	my ($r) = @_;
	$r->res->content_type('text/plain');
	$r->res->content(encode_utf8 $r->render('robots.txt'));
}

sub test {
	my ($r) = @_;
	$r->stash(test => 1);
	$r->res->content(encode_utf8 $r->render('index.html'));
}

1;
