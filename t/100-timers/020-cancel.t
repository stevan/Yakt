#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::System';

subtest 'Cancelled timer does not fire' => sub {
    my $fired = 0;
    my $not_cancelled_fired = 0;

    my $sys = Yakt::System->new->init(sub ($context) {
        my $timer = $context->schedule(
            after    => 0.02,
            callback => sub { $fired++ }
        );

        # Cancel immediately
        $timer->cancel;

        # Schedule another timer that will fire
        $context->schedule(
            after    => 0.01,
            callback => sub { $not_cancelled_fired++ }
        );
    });

    $sys->loop_until_done;

    is($fired, 0, '... cancelled timer did not fire');
    is($not_cancelled_fired, 1, '... non-cancelled timer fired');
};

subtest 'Timer can be cancelled after scheduling' => sub {
    my $fired = 0;

    my $sys = Yakt::System->new->init(sub ($context) {
        my $timer = $context->schedule(
            after    => 0.05,
            callback => sub { $fired++ }
        );

        # Schedule a timer to cancel the first one
        $context->schedule(
            after    => 0.01,
            callback => sub { $timer->cancel }
        );
    });

    $sys->loop_until_done;

    is($fired, 0, '... timer cancelled before it could fire');
};

subtest 'Timer cancelled method reports status' => sub {
    my $timer;

    my $sys = Yakt::System->new->init(sub ($context) {
        $timer = $context->schedule(
            after    => 0.01,
            callback => sub { }
        );

        ok(!$timer->cancelled, '... timer not cancelled initially');
        $timer->cancel;
        ok($timer->cancelled, '... timer is cancelled after cancel()');
    });

    $sys->loop_until_done;
};

done_testing;
