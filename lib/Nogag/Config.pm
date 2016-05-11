package Nogag::Config;

use utf8;
use strict;
use warnings;
use Config::ENV 'PLACK_ENV', export => 'config';
use Path::Class;
use URI;
use constant root => dir(".")->absolute;

common +{
	appname        => 'nogag',
	sitename       => '氾濫原',
	entry_per_page => 3,
	base_uri       => URI->new('https://lowreal.net'),
	postprocess    => URI->new('http://127.0.0.1:13370'),
	version        => scalar time,
	load("app.conf"),
};

config development => {
	db => root->file('db/development.db'),
	cache_db => root->file('db/development-cache.db'),
	postprocess    => URI->new('http://127.0.0.1:13371'),
	explain => 1,
};

config test => {
	username       => 'test',
	password       => 'test',
	postprocess    => URI->new('http://127.0.0.1:13371'),
	db => root->file('db/test.db'),
	cache_db => root->file('db/test-cache.db'),
};

config production => {
	db => root->file('db/data.db'),
	cache_db => root->file('db/cache.db'),
};

config default => { parent('development') };

1;
__END__
