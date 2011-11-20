package Nogag::Config;

use utf8;
use strict;
use warnings;
use Config::ENV 'PLACK_ENV', export => 'config';
use Path::Class;
use constant root => dir(".")->absolute;

common +{
	appname => 'nogag',
	entry_per_page => 7,
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
	db => root->file('db/data.db'),
};

config default => { parent('development') };

1;
__END__
