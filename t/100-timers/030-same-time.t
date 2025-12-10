#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::System';

subtest 'Multiple timers at same time all fire' => sub {
    my $count = 0;

    my $sys = Yakt::System->new->init(sub ($context) {
        # Schedule multiple timers for the same time
        $context->schedule( after => 0.01, callback => sub { $count++ } );
        $context->schedule( after => 0.01, callback => sub { $count++ } );
        $context->schedule( after => 0.01, callback => sub { $count++ } );
    });

    $sys->loop_until_done;

    is($count, 3, '... all timers at same time fired');
};

subtest 'Timers at same time fire together' => sub {
    my @results;

    my $sys = Yakt::System->new->init(sub ($context) {
        # First batch at 0.01
        $context->schedule( after => 0.01, callback => sub { push @results => 'a' } );
        $context->schedule( after => 0.01, callback => sub { push @results => 'b' } );

        # Second batch at 0.02
        $context->schedule( after => 0.02, callback => sub { push @results => 'c' } );
        $context->schedule( after => 0.02, callback => sub { push @results => 'd' } );
    });

    $sys->loop_until_done;

    is(scalar @results, 4, '... all timers fired');
    # a and b should come before c and d (order within batch may vary)
    my $a_idx = 0; $a_idx++ until $results[$a_idx] eq 'a' || $a_idx > $#results;
    my $c_idx = 0; $c_idx++ until $results[$c_idx] eq 'c' || $c_idx > $#results;
    ok($a_idx < $c_idx, '... first batch fired before second batch');
};

done_testing;
