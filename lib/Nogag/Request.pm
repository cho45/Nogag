package Nogag::Request;

use utf8;
use strict;
use warnings;
use parent qw(Plack::Request);
use Hash::MultiValue;
use Encode;

sub parameters {
	my $self = shift;

	$self->env->{'plack.request.merged'} ||= do {
		my $query = $self->query_parameters;
		my $body  = $self->body_parameters;
		my $path  = $self->path_parameters;
		Hash::MultiValue->new($path->flatten, $query->flatten, $body->flatten);
	};
}

sub path_parameters {
	my $self = shift;

	if (@_ > 1) {
		$self->{_path_parameters} = Hash::MultiValue->new(@_);
	}

	$self->{_path_parameters} ||= Hash::MultiValue->new;
}

sub number_param {
	my ($self, $key, $limit) = @_;
	my $val = $self->param($key) // "";
	if ($val =~ /^[\d.]+$/) {
		my $ret = $val + 0;
		if ($ret <= $limit) {
			$ret;
		} else {
			$limit;
		}
	} else {
		undef;
	}
}

sub string_param {
	my ($self, $key) = @_;
	my $val = $self->param($key) // "";
	decode_utf8 $val;
}

sub if_none_match {
	my ($self, $etag) = @_;
	my $match = $self->header('If-None-Match') || '';
	$match ne $etag;
}

sub is_super_reload {
	my ($self) = @_;
	my $cache_control = $self->header('Cache-Control') || '';
	$cache_control eq 'no-cache';
}

1;
