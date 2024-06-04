#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Test::More;

use ok 'Acktor::System';

my $COUNT = 0;

my $sys = Acktor::System->new->init(sub ($context) {
    $COUNT++;
    say $COUNT;
});

$sys->loop_until_done;

is($COUNT, 1, '... got the expected count');

done_testing;

