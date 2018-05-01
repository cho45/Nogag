use strict;
use warnings;
use lib 't/lib';

use Test::Time;
use Test::More;
use Test::Name::FromLine;
use Nogag::Time;



{
	my $time = localtime->from_uri('20180502090000');
	is $time->epoch, 1525219200;
};

{
	my $time = gmtime->from_uri('20180502000000');
	is $time->epoch, 1525219200;
};

done_testing;
