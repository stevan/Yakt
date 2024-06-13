#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::System';

my $COUNT = 0;

my $sys = Yakt::System->new->init(sub ($context) {
    $COUNT++;
});

$sys->loop_until_done;

is($COUNT, 1, '... got the expected count');

done_testing;

