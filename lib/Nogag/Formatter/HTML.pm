package Nogag::Formatter::HTML;

use utf8;
use strict;
use warnings;
use HTML::Entities;

sub format {
	my ($class, $entry) = @_;
	my $body = $entry->body;
	$body =~ s{\Q<![CDATA[\E (.*?) \Q]]>\E}{encode_entities $1}gxes;
	$body;
}

1;
