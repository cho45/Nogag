package Nogag::Test;
$ENV{PLACK_ENV} = 'test';

use utf8;
use strict;
use warnings;

use Exporter::Lite;
use Plack::Util;
use Test::More;
use Test::TCP;
use Test::WWW::Mechanize::PSGI;

use Nogag;
$Nogag::cache->{cache}->Clear;

unlink config->param('db');
Nogag->setup_schema;

our @EXPORT = qw(
	get_entry

	mechanize
	postprocess

	$r
);

our $r = Nogag->new({});

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

sub mechanize {
	my $app  = Plack::Util::load_psgi(config->root->file("script/app.psgi"));
	my $mech = Nogag::Test::Mechanize->new(app => $app);
	$mech->requests_redirectable([]);
	$mech;
};

sub get_entry {
	my ($entry_id) = @_;
	my $entry = $r->dbh->select(q{
		SELECT * FROM entries
		WHERE id = :id
	}, {
		id => $entry_id
	})->[0];

	Nogag::Model::Entry->bless($entry);
}

sub postprocess {
	Test::TCP->new(
		code => sub {
			my $port = shift;
			local $ENV{PORT} = $port;
			exec 'node', './script/postprocess-js-daemon.js';
		}
	);
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
	unless ($mech->{sk}) {
		my $res = $mech->get('/api/edit');
		is($res->code, 200);
		my $json = decode_json($res->content);
		ok($json->{html});
		ok($json->{sk});
		$mech->{sk} =  $json->{sk};
	}
	{
		my $res = $mech->post('/api/edit', {
			%opts,
			sk => $mech->{sk},
		});
		is($res->code, 302);
		my $entry_id = $res->header('X-Entry');
	}
}

sub get_and_cache_created_ok {
	my ($mech, $path) = @_;

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
	};
}

sub get_cached_ok {
	my ($mech, $path) = @_;
	{
		my $res = $mech->get($path);
		is($res->code, 200);
		is($res->header('X-Cache'), 'HIT');
	};
}


1;
__END__
