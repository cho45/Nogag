#!/usr/bin/env perl

use utf8;
use strict;
use warnings;
use v5.10.0;
use lib lib => glob 'modules/*/lib';

use UNIVERSAL::require;
use Encode;

use Nogag;
use Nogag::Model::Entry;
use Nogag::Service::Entry;

my $r = Nogag->new({});
$r->service('Nogag::Service::Entry')->publish_scheduled_entries;

