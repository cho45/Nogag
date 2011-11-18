#!/usr/bin/env perl

use utf8;
use strict;
use warnings;
use lib lib => glob 'modules/*/lib';
use lib lib => "$ENV{HOME}/project/Text-Xatena/lib";


use Nogag::Formatter::Hatena;

warn Nogag::Formatter::Hatena->format(q{
>http://www.aozora.gr.jp/cards/000035/files/275_13903.html:title>
aaa
<<
});
