#!/home/cho45/perl5/perlbrew/perls/perl-5.14.2/bin/perl

use utf8;
use strict;
use warnings;
use lib lib => glob 'modules/*/lib';
use lib lib => "$ENV{HOME}/project/Text-Xatena/lib";


use Nogag::Formatter::Hatena;
use Nogag::Model::Entry;

warn Nogag::Formatter::Hatena->format(Nogag::Model::Entry->bless({ body => q{
	[asin:B0068U8XIM:detail]
} }));
