package Cache::Invalidatable::SQLite;

use utf8;
use strict;
use warnings;

use DBI;

sub new {
	my ($class, %args) = @_;
	$args{db} or die "must specify db file";
	$args{serializer} or die "must specify serializer";
	$args{deserializer} or die "must specify deserializer";
	bless {
		%args,
	}, $class;
}

sub _dbh {
	my ($self) = @_;
	DBI->connect('dbi:SQLite:' . $self->{db}, "", "", {
		RaiseError => 1,
		sqlite_see_if_its_a_number => 1,
		sqlite_unicode => 0,
	});
}

sub set {
	my ($self, $key, $value, $srcs) = @_;
	
	my $dbh = $self->_dbh;
	$dbh->begin_work;

	$dbh->prepare_cached(q{
		DELETE FROM cache WHERE cache_key = ?
	})->execute($key);

	$dbh->prepare_cached(q{
		INSERT INTO cache (cache_key, content) VALUES (?, ?);
	})->execute($key, $self->{serializer}->($value));

	for my $src (@$srcs) {
		$dbh->prepare_cached(q{
			INSERT INTO cache_relation (cache_key, source_id) VALUES (?, ?);
		})->execute($key, $src);
	}

	$dbh->commit;
	undef $dbh;

	$value;
}

sub get {
	my ($self, $key) = @_;
	my $dbh = $self->_dbh;
	my $cache = $dbh->selectall_arrayref(q{
		SELECT * FROM cache WHERE cache_key = ?
	}, { Slice => {} }, $key)->[0];
	undef $dbh;

	if ($cache) {
		$self->{deserializer}->($cache->{content});
	} else {
		undef;
	}
}

sub remove {
	my ($self, $key) = @_;
	my $dbh = $self->_dbh;
	$dbh->begin_work;
	$dbh->prepare_cached(q{
		DELETE FROM cache WHERE cache_key = ?
	})->execute($key);
	$dbh->commit;
	undef $dbh;
	undef;
}

sub invalidate_related {
	my ($self, $src) = @_;
	my $dbh = $self->_dbh;
	$dbh->begin_work;
	$dbh->prepare_cached(q{
		DELETE FROM cache_relation WHERE source_id = ?
	})->execute($src);
	$dbh->commit;
	undef $dbh;
}

sub clear {
	my ($self) = @_;
	my $dbh = $self->_dbh;
	$dbh->begin_work;
	$dbh->do('DELETE FROM cache');
	$dbh->do('DELETE FROM cache_relation');
	$dbh->commit;
	undef $dbh;
}


1;
__END__

