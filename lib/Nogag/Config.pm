package Nogag::Config;

use utf8;
use strict;
use warnings;
use Config::ENV 'PLACK_ENV', export => 'config';
use Path::Class;
use constant root => dir(".")->absolute;

common +{
	appname => 'nogag',
	load("app.conf-sample"),
};

config development => {
	db => 'db/development.db',
};

config production => {
	db => 'db/data.db',
};

1;
__END__
