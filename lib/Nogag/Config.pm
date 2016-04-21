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
	entry_per_page => 4,
	base_uri => URI->new('https://lowreal.net'),
	link_headers   => '/tmp/lowreal.net.link.txt',
	version        => scalar time,
	load("app.conf"),
};

config development => {
	db => root->file('db/development.db'),
	explain => 1,
};

config test => {
	db => root->file('db/test.db'),
};

config production => {
	link_headers   => '/srv/www/lowreal.net.link.txt',
	db => root->file('db/data.db'),
};

config default => { parent('development') };

1;
__END__
