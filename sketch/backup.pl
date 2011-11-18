#!/usr/bin/env perl

use utf8;
use strict;
use warnings;
use lib lib => glob 'modules/*/lib';

use Nogag::Config;
use Nogag::Time;

use Path::Class;
use Email::MIME;
use Email::Send;

my $compressed = config->param('db') . '.xz';
unlink $compressed;

system(qw/xz -z -9 -k -f/, config->param('db'));

my $name = localtime->strftime('%Y-%m-%d') . $compressed;

my $email = Email::MIME->create(
	header => [
		From    => 'cho45@lowreal.net',
		To      => 'cho45@lowreal.net',
		Subject => 'Backup ' . $name ,
	],

	parts => [
		Email::MIME->create(
			attributes => {
				content_type => 'text/plain',
				charset      => 'iso-2022-jp',
			},
			body => config->param('db'),
		),
		Email::MIME->create(
			attributes => {
				filename     => $name,
				content_type => 'application/x-xz',
				encoding     => 'base64',
				name         => $name,
			},

			body => scalar file($compressed)->slurp,
		),
	]
);

warn length $email->as_string;

#my $sender = Email::Send->new({mailer => 'SMTP'});
#$sender->mailer_args([Host => '192.168.0.19']);
#$sender->send($email);
