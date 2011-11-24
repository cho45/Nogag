package Nogag::Formatter::Markdown;

use utf8;
use strict;
use warnings;

use Text::Markdown 'markdown';

sub format {
	markdown($_[1]->body);
}

1;
