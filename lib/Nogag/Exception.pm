package Nogag::Exception;

use utf8;
use strict;
use warnings;

sub throw {
    my ($class, %opts) = @_;
    die $class->new(%opts);
}

sub new {
    my ($class, %opts) = @_;
    bless \%opts, $class;
}

sub code { $_[0]->{code} }
sub message { $_[0]->{message} }

1;
