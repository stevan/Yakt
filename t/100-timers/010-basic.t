#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::System';

subtest 'Single timer fires' => sub {
    my $fired = 0;

    my $sys = Yakt::System->new->init(sub ($context) {
        $context->schedule(
            after    => 0.01,
            callback => sub { $fired++ }
        );
    });

    $sys->loop_until_done;

    is($fired, 1, '... timer fired once');
};

subtest 'Multiple timers fire in order' => sub {
    my @order;

    my $sys = Yakt::System->new->init(sub ($context) {
        $context->schedule( after => 0.03, callback => sub { push @order => 3 } );
        $context->schedule( after => 0.01, callback => sub { push @order => 1 } );
        $context->schedule( after => 0.02, callback => sub { push @order => 2 } );
    });

    $sys->loop_until_done;

    is_deeply(\@order, [1, 2, 3], '... timers fired in correct order');
};

done_testing;
