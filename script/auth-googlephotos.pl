#!/usr/bin/env perl

use utf8;
use strict;
use warnings;
use v5.10.0;
use lib lib => glob 'modules/*/lib';

use Nogag;
use Nogag::External::GooglePhotos;
use Log::Minimal;
local $Log::Minimal::AUTODUMP = 1;


my $r = Nogag->new({});
$r->setup_schema;


my $service = $r->service('Nogag::Service::GooglePhotos');

if (-t) {
	infof('Authorize');
	$service->authorize;
}

infof("Renew token");
$service->refresh;


