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
	imgcache_root  => root->subdir("imgcache"),
	version        => scalar time,
	load("app.conf"),
};

config development => {
	session => {
		servers => [
			'127.0.0.1:11211'
		],
		namespace => 'nogag-dev',
	},
	db => root->file('db/development.db'),
	cache_db => root->file('db/development-cache.db'),
	config_db => root->file('db/development-config.db'),
	tfidf_db => root->file('db/development-tfidf.db'),
	worker_db => root->file('db/development-worker.db'),
	postprocess    => URI->new('http://127.0.0.1:13371'),
	images_db => root->file('db/development-images.db'),
	explain => 0,
};

config test => {
	session => {
		servers => [
			'127.0.0.1:11211'
		],
		namespace => 'nogag-test',
	},
	username       => 'test',
	password       => 'test',
	postprocess    => URI->new('http://127.0.0.1:13371'),
	db => root->file('db/test.db'),
	cache_db => root->file('db/test-cache.db'),
	config_db => root->file('db/test-config.db'),
	tfidf_db => root->file('db/test-tfidf.db'),
	worker_db => root->file('db/test-worker.db'),
	images_db => root->file('db/test-images.db'),
};

config production => {
	session => {
		servers => [
			'127.0.0.1:11211'
		],
		namespace => 'nogag-',
	},
	db => root->file('db/data.db'),
	cache_db => root->file('db/cache.db'),
	config_db => root->file('db/config.db'),
	tfidf_db => root->file('db/tfidf.db'),
	worker_db => root->file('db/worker.db'),
	images_db => root->file('db/images.db'),
};

config default => { parent('development') };

1;
__END__
