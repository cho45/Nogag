package Nogag::Test;
BEGIN { $ENV{PLACK_ENV} = 'test' };

use utf8;
use strict;
use warnings;

use Test::More;
use Test::TCP;
use Test::Time;

use Exporter::Lite;
use Plack::Util;
use Plack::Request;
use Test::WWW::Mechanize::PSGI;
use HTML::TreeBuilder::XPath;
use Plack::Loader;
use TheSchwartz;
use UNIVERSAL::require;

use Nogag;

unlink config->param('db');
unlink config->param('cache_db');

our @EXPORT = qw(
	get_entry
	create_entry
	cleanup_database

	work

	mechanize
	postprocess
	tree
);

cleanup_database();

no warnings 'redefine';
sub import {
	my $class = caller(0);
	no warnings 'redefine';
	no strict 'refs';

	*{"$class\::subtest"} = sub {
		my ($name, $subtests) = @_;
		note "\nsubtest $name\n\n";
		goto &$subtests;
	};

	goto &Exporter::Lite::import;
};

sub tree {
	HTML::TreeBuilder::XPath->new_from_content($_[0]);
}

sub work {
	my ($funcname) = @_;
	note "work $funcname";
	$funcname->use;
	my $databases = [ { dsn => 'dbi:SQLite:' . config->param('worker_db'), user => '', pass => '' } ];
	my $client = TheSchwartz->new( databases => $databases );
	$client->can_do($funcname);
	$client->work_until_done;
}

sub mechanize {
	my $app  = Plack::Util::load_psgi(config->root->file("script/app.psgi"));
	my $mech = Nogag::Test::Mechanize->new(app => $app);
	$mech->requests_redirectable([]);
	$mech;
};

sub cleanup_database {
	note "CLEANUP DATABASE";
	unlink config->param('db');
	unlink config->param('cache_db');
	unlink config->param('config_db');
	unlink config->param('tfidf_db');
	unlink config->param('worker_db');
	unlink config->param('images_db');
	Nogag->setup_schema;
}

sub get_entry {
	my ($entry_id) = @_;
	my $entry = Nogag->new({})->dbh->select(q{
		SELECT * FROM entries
		WHERE id = :id
	}, {
		id => $entry_id
	})->[0];

	Nogag::Model::Entry->bless($entry);
}

sub create_entry {
	my (%params) = @_;
	my $r = Nogag->new({});
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
		%params
	});

	my $id = $r->dbh->sqlite_last_insert_rowid;
	$r->retrieve_entry_by_id($id);
}

sub postprocess {
	my (%opts) = @_;
	my $guard = $opts{dummy} ? 
		Test::TCP->new(
			code => sub {
				my $port = shift;
				Plack::Loader->load('Standalone',
					port => $port
				)->run(sub {
					my $env = shift;
					my $req = Plack::Request->new($env);
					my $res = $req->new_response(200);
					$res->content($req->content);
					$res->finalize;
				});
			}
		):
		Test::TCP->new(
			code => sub {
				my $port = shift;
				local $ENV{PORT} = $port;
				exec 'node', './script/postprocess-js-daemon.js';
			}
		);
	$guard->{config_guard} = config->local(
		postprocess    => URI->new('http://127.0.0.1:' . $guard->port),
	);
	$guard;
}

package Nogag::Test::Mechanize;

use parent qw(Test::WWW::Mechanize::PSGI);
use Test::More;
use JSON;

sub login {
	my ($mech) = @_;
	unless ($mech->{auth}) {
		$mech->get('/login');
		$mech->submit_form(
			with_fields => {
				username => 'test',
				password => 'test',
			}
		);
		note "logged-in";
	}
	$mech->{auth} = 1;
}

sub logout {
	my ($mech) = @_;
	$mech->get('/logout');
}

sub edit {
	my ($mech, %opts) = @_;
	local $Test::Builder::Level = $Test::Builder::Level + 1;
	unless ($mech->{sk}) {
		my $res = $mech->get('/api/edit');
		is($res->code, 200);
		my $json = decode_json($res->content);
		ok($json->{html}) or die $res;
		ok($json->{sk}) or die $res;
		$mech->{sk} =  $json->{sk};
	}
	{
		my $res = $mech->post('/api/edit', {
			status => 'public',
			%opts,
			sk => $mech->{sk},
		});
		is($res->code, 200);
		Nogag::Test::work('Nogag::Worker::PostEntry');
		my $entry_id = $res->header('X-Entry');
		return $entry_id;
	}
}

sub get_and_cache_created_ok {
	my ($mech, $path) = @_;
	local $Test::Builder::Level = $Test::Builder::Level + 1;

	unless ($path =~ qr{^/}) {
		$path = "/" . $path;
	}

	{
		my $res = $mech->get($path);
		is($res->code, 200);
		is($res->header('X-Cache'), undef);
	};

	{
		my $res = $mech->get($path);
		is($res->code, 200);
		is($res->header('X-Cache'), 'HIT');
		$res;
	};
}

sub get_cached_ok {
	my ($mech, $path) = @_;
	local $Test::Builder::Level = $Test::Builder::Level + 1;
	my $res = $mech->get($path);
	is($res->code, 200);
	is($res->header('X-Cache'), 'HIT');
	$res;
}

sub get_dispatched_ok {
	my ($mech, $path, $pattern) = @_;
	local $Test::Builder::Level = $Test::Builder::Level + 1;
	my $res = $mech->get($path);
	is($res->code, 200);
	is($res->header('X-Dispatch'), $pattern);
	$res;
}

1;
__END__
