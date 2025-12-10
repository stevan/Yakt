#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::System';

my @STOP_ORDER;

class SlowChild :isa(Yakt::Actor) {
    field $name :param;
    field $delay :param = 0;

    method on_stopping :Signal(Yakt::System::Signals::Stopping) ($context, $signal) {
        # Simulate some cleanup work
        if ($delay > 0) {
            $context->schedule(
                after    => $delay,
                callback => sub { }  # Just delay
            );
        }
    }

    method on_stopped :Signal(Yakt::System::Signals::Stopped) ($context, $signal) {
        push @STOP_ORDER => $name;
    }
}

class StopMe :isa(Yakt::Message) {}

class ParentWithChildren :isa(Yakt::Actor) {
    method on_started :Signal(Yakt::System::Signals::Started) ($context, $signal) {
        $context->spawn(Yakt::Props->new(
            class => 'SlowChild',
            args  => { name => 'child1', delay => 0 }
        ));
        $context->spawn(Yakt::Props->new(
            class => 'SlowChild',
            args  => { name => 'child2', delay => 0 }
        ));
    }

    method on_stopped :Signal(Yakt::System::Signals::Stopped) ($context, $signal) {
        push @STOP_ORDER => 'parent';
    }

    method on_stop :Receive(StopMe) ($context, $message) {
        $context->stop;
    }
}

subtest 'Parent waits for children to stop before completing' => sub {
    @STOP_ORDER = ();

    my $sys = Yakt::System->new->init(sub ($context) {
        my $parent = $context->spawn(Yakt::Props->new( class => 'ParentWithChildren' ));

        $context->schedule(
            after    => 0.01,
            callback => sub { $parent->send(StopMe->new) }
        );
    });

    $sys->loop_until_done;

    is(scalar @STOP_ORDER, 3, '... all actors stopped');
    is($STOP_ORDER[-1], 'parent', '... parent stopped last (after children)');
};

done_testing;
