package Cache::Invalidatable;

use utf8;
use strict;
use warnings;
use Scalar::Util qw(weaken);

sub new {
	my ($class, %args) = @_;
	$args{cache} or die "must specify parent cache instance";
	bless {
		%args,
	}, $class;
}

sub set {
	my ($self, $key, $value, $srcs) = @_;

	my $container = [$value, [ @$srcs ] ];
	$self->{cache}->set($key, $container);

	if (@$srcs) {
		do {
			my $sources = $self->{cache}->get('__sources') || {};
			for my $src (@$srcs) {
				$sources->{$src}->{$key} = 1;
			}
			$self->{cache}->set('__sources' => $sources);
		} while (!$self->{cache}->get('__sources')->{ $srcs->[0] }->{$key});
	}

	$value;
}

sub get {
	my ($self, $key) = @_;
	my $got = $self->{cache}->get($key);
	return undef unless $got;
	$got->[0];
}

sub remove {
	my ($self, $key) = @_;
	my $got = $self->{cache}->get($key);
	$self->{cache}->remove($key);
	return undef unless $got;
	my ($value, $srcs) = @$got;
	my $sources = $self->{cache}->get('__sources') || {};
	for my $src (@$srcs) {
		delete $sources->{$src}->{$key};
		if (!%{ $sources->{$src} }) {
			delete $sources->{$src};
		}
	}
	$self->{cache}->set('__sources' => $sources);

	$value;
}

sub invalidate_related {
	my ($self, $src) = @_;
	my $sources = $self->{cache}->get('__sources') || {};
	my $keys = delete $sources->{$src};
	$self->{cache}->set('__sources' => $sources);
	for my $key (keys %$keys) {
		$self->remove($key);
	}
}

1;
__END__
