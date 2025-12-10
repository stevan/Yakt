#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::System';

subtest 'Timer callback error does not crash system' => sub {
    my $before_error = 0;
    my $after_error = 0;

    my $sys = Yakt::System->new->init(sub ($context) {
        $context->schedule(
            after    => 0.01,
            callback => sub { $before_error++ }
        );

        $context->schedule(
            after    => 0.02,
            callback => sub { die "Timer error!" }
        );

        $context->schedule(
            after    => 0.03,
            callback => sub { $after_error++ }
        );
    });

    $sys->loop_until_done;

    is($before_error, 1, '... timer before error fired');
    is($after_error, 1, '... timer after error still fired');
};

subtest 'Multiple timer errors in same batch are handled' => sub {
    my $success_count = 0;

    my $sys = Yakt::System->new->init(sub ($context) {
        $context->schedule( after => 0.01, callback => sub { die "Error 1" } );
        $context->schedule( after => 0.01, callback => sub { $success_count++ } );
        $context->schedule( after => 0.01, callback => sub { die "Error 2" } );
        $context->schedule( after => 0.01, callback => sub { $success_count++ } );
    });

    $sys->loop_until_done;

    is($success_count, 2, '... successful callbacks still executed despite errors');
};

done_testing;
