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
use Cache::FileCache;
use Log::Minimal;
use JSON::XS;
use List::Util qw(reduce);

use Nogag::Base;
use Nogag::Time;
use Nogag::Model::Entry;
use Nogag::Utils;
use Cache::Invalidatable::SQLite;
use Compress::Zlib;

use Nogag::Formatter::Hatena;
use Nogag::Service::Cache;
use Nogag::Service::Entry;

use parent qw(Nogag::Base);

our @EXPORT = qw(config throw);

route "/" => \&index;
route "/.page/{page:[0-9]{8}}/{epp:[0-9]}" => \&index;
route "/headline" => \&headline;
route "/login" => \&login;
route "/logout" => \&logout;
route "/sitemap.xml" => \&sitemap;
route "/feed" => \&feed;
route "/robots.txt" => \&robots_txt;
route "/test" => \&test;

route "/edit" => \&edit_form;
route "/api/edit" => \&edit;
route "/api/edit/progress" => \&edit_progress;
route "/api/kousei" => "Nogag::API kousei";
route "/api/similar" => \&similar;
route "/api/exif" => \&exif;

# route '/{year:[0-9]{4}}/' => \&archive;
route '/{year:[0-9]{4}}/{month:[0-9]{2}}/' => \&archive;
route '/{year:[0-9]{4}}/{month:[0-9]{2}}/{day:[0-9]{2}}/' => \&archive;
route '/archive' => \&archive_index;
route '/:category_name/' => \&category;
route "/:category_name/.page/{page:[0-9]{14}}/{epp:[0-9]}" => \&category;
route '/{path:.+}' => \&permalink;

sub login {
	my ($r) = @_;

	if ($r->req->method eq 'POST') {
		my $username = $r->req->param('username') // '';
		my $password = $r->req->param('password') // '';
		if ($username eq config->param('username') && $password eq config->param('password')) {
			$r->session->set('auth' => 1);
			throw code => 302, location => '/?' . scalar time;
		} else {
			$r->stash('error' => 'Invalid Username or Password');
		}
	}

	$r->session->set('login' => 1); # ensure create session
	$r->html('login.html');
}

sub logout {
	my ($r) = @_;
	$r->session->expire;
	$r->redirect('/');
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

	if ($r->req->method eq 'GET') {
		$r->json(+{
			html => $r->render('form.html'),
			sk => $r->sk,
		});
	} elsif ($r->req->method eq 'POST') {
		$r->service('Nogag::Service::Cache')->set('progress', => 'saving');

		my $invalidate_target = '/';
		if ($entry->id) {
			$entry = $r->service('Nogag::Service::Entry')->update_entry($entry,
				title          => $r->req->string_param('title'),
				body           => $r->req->string_param('body'),
			);

			$invalidate_target = "".$entry->id;;
		} else {
			$entry = $r->service('Nogag::Service::Entry')->create_new_entry(
				title          => $r->req->string_param('title'),
				body           => $r->req->string_param('body'),
			);
			$invalidate_target = '/';
		}

		$r->service('Nogag::Service::Cache')->set('progress', => 'update-similar-entries');
		$r->service('Nogag::Service::SimilarEntry')->update($entry);

		$r->service('Nogag::Service::Cache')->set('progress', => 'posting-new-job');
		$r->work_job('Nogag::Worker::PostEntry', {
			entry => $entry,
			invalidate_target => $invalidate_target,
		}, uniqkey => 'postentry-' . $entry->id);

		if ($r->req->param('post_buffer')) {
			$r->work_job('Nogag::Worker::PostBuffer', {
				entry => $entry,
			}, uniqkey => 'postbuffer-' . $entry->id);
		}

		$r->service('Nogag::Service::Cache')->set('progress', => '');
		$r->res->header('X-Entry', $entry->id);
		$r->json(+{
			id => $entry->id,
			location => $entry->path('/')
		});
	} else {
		$r->json(+{
			error => 'Invalid request method'
		});
	}
}

sub edit_progress {
	my ($r) = @_;
	return $r->json({ error => 'require authentication' }) unless $r->has_auth;

	my $progress = $r->service('Nogag::Service::Cache')->get('progress');
	$r->json(+{
		progress => $progress
	});
}

sub edit_form {
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
	};

	$r->stash(entry_json => encode_json($entry ? {
		id => $entry->{id},
		title => $entry->{title},
		body => $entry->{body},
	} : {
		id => '',
		title => '',
		body  => '',
	}));


	$r->html('edit.tt');
}

sub index {
	my ($r) = @_;
	my $page = $r->req->date_param('page') || '';
	my $epp  = $r->req->number_param('epp', 30) || config->param('entry_per_page');

	$r->res->header('Cache-Control' => 'public, max-age=0, must-revalidate');

	my $cache_key = join(":", $r->has_auth ? 'a' : 'b', $r->req->path, $page, $epp);
	unless ($r->has_auth) {
		if ( (my $cached = Nogag::Service::Cache->get($cache_key)) && !$r->req->is_super_reload) {
			infof("return cache: %s", $cache_key);
			$r->{res} = Nogag::Response->new(@$cached);
			$r->res->header('X-Cache', 'HIT');
			my $etag = $r->res->header('ETag');
			$r->req->if_none_match($etag) or throw code => 304, message => 'Not Modified';
			return;
		}
	}

	my $entries;
	my $dates = $r->dbh->select(q{
		SELECT `date` FROM entries
		WHERE `date` <= :page
		GROUP BY `date`
		ORDER BY `date` DESC
		LIMIT :limit
	}, {
		page   => $page ? $page->strftime('%Y-%m-%d') : '9999-99-99',
		limit  => $epp + 1,
	});

	my $next_page;
	if (@$dates > $epp) {
		$next_page = localtime->from_db((pop @$dates)->{date})->strftime('%Y%m%d');
	}

	$entries = $r->dbh->select(q{
		SELECT * FROM entries
		WHERE `date` IN (:dates)
		ORDER BY `date` DESC, `created_at` ASC
	}, {
		dates => [ map { $_->{date} } @$dates ]
	});

	Nogag::Model::Entry->bless($_) for @$entries;
	$r->service('Nogag::Service::Trackback')->fill_trackbacks($_) for @$entries;
	# $r->service('Nogag::Service::SimilarEntry')->fill_similar_entries($_) for @$entries;

	my $count = $r->dbh->value('SELECT count(*) FROM entries');

	@$entries or $r->res->status(404);

	$r->stash(mathjax => enable_mathjax(@$entries));

	if (@$entries) {
		my $modified_at = [ sort { $b->modified_at <=> $a->modified_at } @$entries]->[0]->modified_at;
		my $etag = md5_hex(join("\n", $modified_at->epoch, -s $r->config->root->file('templates/index.html')));
		# キャッシュから返すときだけ304
		# $r->req->if_none_match($etag) or throw code => 304, message => 'Not Modified';
		$r->res->header('ETag' => $etag);
		$r->res->header('Last-Modified' => $modified_at->strftime('%a, %d %b %Y %H:%M:%S GMT'));
	}

	my $title = $page ? sprintf("%d年%d月%d日以前の%d日", $page->strftime('%Y'), $page->strftime('%m'), $page->strftime('%d'), $epp):
	            "";

	$r->stash(title => $title);
	$r->stash(entries => $entries);
	$r->stash(count => $count);
	$r->stash(next_page => do {
		if ($next_page) {
			sprintf('/.page/%s/%s', $next_page, $epp);
		}
	});

	$r->html('index.html');
	infof("new cache: %s", $cache_key);
	if (my $compressed = Compress::Zlib::memGzip($r->res->body)) {
		$r->res->header('Content-Encoding', 'gzip');
		$r->res->body($compressed);
	} else {
		warn "Cannot compress: $gzerrno\n";
	}
	Nogag::Service::Cache->set($cache_key => $r->res->finalize, [ ($page ? () : "/"), map { $_->id } @$entries ]);
}

sub headline {
	my ($r) = @_;

	my $page = $r->req->date_param('page') || '';
	my $epp  = 10;

	my $entries;
	my $dates = $r->dbh->select(q{
		SELECT `date` FROM entries
		WHERE `date` <= :page
		GROUP BY `date`
		ORDER BY `date` DESC
		LIMIT :limit
	}, {
		page   => $page ? $page->strftime('%Y-%m-%d') : '9999-99-99',
		limit  => $epp + 1,
	});

	my $next_page;
	if (@$dates > $epp) {
		$next_page = localtime->from_db((pop @$dates)->{date})->strftime('%Y%m%d');
	}

	$entries = $r->dbh->select(q{
		SELECT * FROM entries
		WHERE `date` IN (:dates)
		ORDER BY `date` DESC, `created_at` ASC
	}, {
		dates => [ map { $_->{date} } @$dates ]
	});

	Nogag::Model::Entry->bless($_) for @$entries;

	$r->stash(headline => $entries);
	$r->stash(next_page => do {
		if ($next_page) {
			sprintf('/headline?page=%s', $next_page);
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

	my $cache_key = join(":", $r->has_auth ? 'a' : 'b', $r->req->path);

	unless ($r->has_auth) {
		if ( (my $cached = Nogag::Service::Cache->get($cache_key)) && !$r->req->is_super_reload) {
			infof("return cache: %s", $cache_key);
			$r->{res} = Nogag::Response->new(@$cached);
			$r->res->header('X-Cache', 'HIT');
			my $etag = $r->res->header('ETag');
			$r->req->if_none_match($etag) or throw code => 304, message => 'Not Modified';
			return;
		}
	}

	my $entry = $r->dbh->select(q{
		SELECT * FROM entries
		WHERE path = :path
	}, {
		path => $path,
	})->[0] or throw code => 404, message => 'Not Found';

	Nogag::Model::Entry->bless($entry);
	$r->service('Nogag::Service::Trackback')->fill_trackbacks($entry);
	# $r->service('Nogag::Service::SimilarEntry')->fill_similar_entries($entry);

	my $etag = md5_hex(join("\n", $entry->modified_at->epoch, -s $r->config->root->file('templates/index.html')));
	# キャッシュから返す場合だけ304
	# $r->req->if_none_match($etag) or throw code => 304, message => 'Not Modified';
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

	my $entries = [ $entry ];

	$r->stash(mathjax => enable_mathjax(@$entries));

	$r->stash(entries => $entries);
	$r->stash(entry => $entry);
	$r->stash(permalink => 1);
	$r->stash(old_entry => $old_entry);
	$r->stash(new_entry => $new_entry);
	$r->stash(title => $entry->title_for_permalink);

	$r->html('index.html');
	infof("new cache: %s", $cache_key);
	if (my $compressed = Compress::Zlib::memGzip($r->res->body)) {
		$r->res->header('Content-Encoding', 'gzip');
		$r->res->body($compressed);
	} else {
		warn "Cannot compress: $gzerrno\n";
	}
	Nogag::Service::Cache->set($cache_key => $r->res->finalize, [ $entry->id ]);
}

sub category {
	my ($r) = @_;

	my $page = $r->req->time_param('page') || '';
	my $epp  = $r->req->number_param('epp', 30) || config->param("entry_per_page");
	my $name = lc $r->req->param('category_name');

	my $cache_key = join(":", $r->has_auth ? 'a' : 'b', $r->req->path, $page, $epp);

	unless ($r->has_auth) {
		if ( (my $cached = Nogag::Service::Cache->get($cache_key)) && !$r->req->is_super_reload) {
			infof("return cache: %s", $cache_key);
			$r->{res} = Nogag::Response->new(@$cached);
			$r->res->header('X-Cache', 'HIT');
			my $etag = $r->res->header('ETag');
			$r->req->if_none_match($etag) or throw code => 304, message => 'Not Modified';
			return;
		}
	}

	my $entries = $r->dbh->select(q{
		SELECT * FROM entries
		WHERE `created_at` <= :page AND title LIKE :query
		ORDER BY `date` DESC, `created_at` ASC
		LIMIT :limit
	}, {
		page  => $page ? "$page" : '9999-99-99 99:99:99',
		query => "%[$name]%",
		limit => $epp + 1,
	});
	Nogag::Model::Entry->bless($_) for @$entries;

	my $next_page;
	if (@$entries > $epp) {
		$next_page = localtime((pop @$entries)->created_at->epoch)->for_uri;
	}

	$r->service('Nogag::Service::Trackback')->fill_trackbacks($_) for @$entries;
	# $r->service('Nogag::Service::SimilarEntry')->fill_similar_entries($_) for @$entries;

	my $count = $r->dbh->value('SELECT count(*) FROM entries');

	@$entries or $r->res->status(404);
	$r->stash(mathjax => enable_mathjax(@$entries));

	if (@$entries) {
		my $modified_at = [ sort { $b->modified_at <=> $a->modified_at } @$entries]->[0]->modified_at;
		my $etag = md5_hex(join("\n", $modified_at->epoch, -s $r->config->root->file('templates/index.html')));
		# キャッシュから返す場合だけ 304 を返す
		# $r->req->if_none_match($etag) or throw code => 304, message => 'Not Modified';
		$r->res->header('ETag' => $etag);
		$r->res->header('Last-Modified' => $modified_at->strftime('%a, %d %b %Y %H:%M:%S GMT'));
	}

	my $title = $page ? sprintf("%s カテゴリー「%s」以前の%d件", ucfirst $name, $entries->[0]->title || $entries->[0]->path, $epp):
	            sprintf('%s カテゴリー', ucfirst $name);

	$r->stash(category => $name);
	$r->stash(title => $title);
	$r->stash(entries => $entries);
	$r->stash(count => $count);
	$r->stash(next_page => do {
		if ($next_page) {
			sprintf('/%s/.page/%s/%s', $name, $next_page, $epp);
		}
	});

	my $tmpl = config->root->subdir('templates/category')->file("$name.html");
	if (-e $tmpl) {
		return $r->html($tmpl);
	} else {
		$r->html('index.html');
		infof("new cache: %s", $cache_key);
		if (my $compressed = Compress::Zlib::memGzip($r->res->body)) {
			$r->res->header('Content-Encoding', 'gzip');
			$r->res->body($compressed);
		} else {
			warn "Cannot compress: $gzerrno\n";
		}
		Nogag::Service::Cache->set($cache_key => $r->res->finalize, [ ($page ? () : "/"), map { $_->id } @$entries ]);
	}
}

sub sitemap {
	my ($r) = @_;

	my $entries = $r->dbh->select(q{
		SELECT
			path,
			strftime('%Y%m%d', date) as date,
			strftime('%Y-%m-%dT%H:%M:%SZ', modified_at) as lastmod
		FROM entries
		ORDER BY `date` DESC
	});

	my $dates = $r->dbh->select(q{
		SELECT
			strftime('/%Y/%m/%d/', date) as date
		FROM entries
		GROUP BY date
	});

	my $months = $r->dbh->select(q{
		SELECT
			strftime('/%Y/%m/', date) as month
		FROM entries
		GROUP BY month
	});

	$r->stash(entries => $entries);
	$r->stash(dates => $dates);
	$r->stash(months => $months);

	$r->res->content_type('application/xml; charset=utf-8');
	$r->res->content(encode_utf8 $r->render('sitemap.xml'));
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

sub similar {
	my ($r) = @_;
	my @ids = $r->req->param('id');


	my $result = {
		map {
			my $html;

			my $entries = $r->service('Nogag::Service::SimilarEntry')->get_similar_entries($_);
			if (@$entries) {
				$html = $r->render('_similar.html', {
					similar_entries => $entries,
				});
			} else {
				my $photos = $r->service('Nogag::Service::SimilarImage')->get_similar_photos_by_entry_id($_, limit => 3);
				my $entries = $r->dbh->select(q{
					SELECT * FROM entries
					WHERE id IN (:ids)
				}, {
					ids => [
						map {
							$_->{entry_id}
						}
						@$photos
					]
				});
				my $map = reduce { $a->{$b->{id}} = $b; $a } +{}, @$entries;
				for my $photo (@$photos) {
					$photo->{entry} = Nogag::Model::Entry->bless($map->{$photo->{entry_id}});
				}
				$html = $r->render('_similar_images.html', {
					similar_images => $photos
				});
			}
			$html =~ s/^\s+|\s+$//g;
			$html ? ($_ => $html) : ()
		} @ids
	};

	my $ad = $r->render('_affiliate.html', {
	});

	$r->res->header('Cache-Control' => 'max-age=3600');
	$r->json({
		result => $result,
		ad => $ad,
	});
}

sub exif {
	my ($r) = @_;
	my @ids = $r->req->param('id');
	my $entries = $r->dbh->select(q{
		SELECT * FROM entries
		WHERE id IN (:ids)
	}, {
		ids => \@ids
	});

	my $picasa = $r->service('Nogag::Service::Picasa');

	my $result = {};
	for my $entry (@$entries) {
		Nogag::Model::Entry->bless($entry);
		my $targets = [ $entry->body =~ m{(https://picasaweb.google.com/\d+/[^/#]+#\d+)}g ];
		for my $target (@$targets) {
			eval {
				infof("extract exif %s", $target);
				my $exif = $picasa->extract_exif($target) ;
				local $Log::Minimal::AUTODUMP = 1;
				infof("extract exif %s -> %s", $target, $exif);
				delete $exif->{original_uri};
				delete $exif->{uri};
				$result->{$target} = $exif;
			};
			if ($@) {
				warnf("failed to extract_exif %s", $@);
			}
		}
	}

	$r->json({
		result => $result,
	});
}

sub robots_txt {
	my ($r) = @_;
	$r->res->content_type('text/plain');
	$r->res->content(encode_utf8 $r->render('robots.txt'));
}

sub test {
	my ($r) = @_;
	$r->res->streaming(sub {
		my $responder = shift;
		my $writer = $responder->([ 200, [ 'Content-Type', 'multipart/x-mixed-replace; boundary=boundary' ]]);
		warn "foo:1";
		$writer->write("--boundary\r\n");
		$writer->write("Content-Type: application/json\r\n");
		$writer->write("\r\n");
		$writer->write("{foo:1}");
		$writer->write("\r\n\r\n");
		sleep 3;
		warn "bar:2";
		$writer->write("--boundary\r\n");
		$writer->write("Content-Type: application/json\r\n");
		$writer->write("\r\n");
		$writer->write("{bar:2}");
		$writer->write("\r\n\r\n");
		sleep 3;
		$writer->close;
	});
}

sub like_mathjax {
	my ($html) = @_;
	$html =~ /\\\(|\$\$/;
}

sub enable_mathjax {
	my (@entries) = @_;
	!!grep { like_mathjax($_->formatted_body(1)) } @entries;
}

1;
