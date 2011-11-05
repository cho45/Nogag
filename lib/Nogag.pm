package Nogag;

use strict;
use warnings;

use Nogag::Base;
use parent qw(Nogag::Base);

our @EXPORT = qw(config throw);

route "/" => sub {
	$_->res->content('Hello, World!');
};

1;
