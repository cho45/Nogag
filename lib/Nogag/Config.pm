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
	db => 'db/development.db',
	explain => 1,
};

config test => {
	db => 'db/test.db',
};

config production => {
	db => 'db/data.db',
};

config default => { parent('development') };

1;
__END__
