#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Acktor::System';

my $COUNT = 0;
my @RESULTS;

my $sys = Acktor::System->new->init(sub ($context) {

    $context->schedule( after => 0.1, callback => sub {
        push @RESULTS => [ 1, $COUNT++ ];
    });

    $context->schedule( after => 0.4, callback => sub {
        push @RESULTS => [ 4, $COUNT++ ];
    });

    $context->schedule( after => 0.2, callback => sub {
        push @RESULTS => [ 2, $COUNT++ ];
    });
});

$sys->loop_until_done;

is($COUNT, 3, '... got the expected count');
is_deeply(\@RESULTS, [[1,0],[2,1],[4,2]], '... got the expected results');

done_testing;

