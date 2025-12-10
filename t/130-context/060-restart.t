#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::System';

class TriggerRestart :isa(Yakt::Message) {}

class RestartableActor :isa(Yakt::Actor) {
    our $STARTED_COUNT    = 0;
    our $RESTARTING_COUNT = 0;
    our $MESSAGE_COUNT    = 0;

    method on_started :Signal(Yakt::System::Signals::Started) ($context, $signal) {
        $STARTED_COUNT++;
    }

    method on_restarting :Signal(Yakt::System::Signals::Restarting) ($context, $signal) {
        $RESTARTING_COUNT++;
    }

    method on_trigger :Receive(TriggerRestart) ($context, $message) {
        $MESSAGE_COUNT++;
        if ($RESTARTING_COUNT < 2) {
            # Re-send message to ourselves before restarting
            $context->self->send(TriggerRestart->new);
            $context->restart;
        } else {
            # After 2 restarts, stop
            $context->stop;
        }
    }
}

subtest 'context->restart triggers restart sequence' => sub {
    $RestartableActor::STARTED_COUNT    = 0;
    $RestartableActor::RESTARTING_COUNT = 0;
    $RestartableActor::MESSAGE_COUNT    = 0;

    my $sys = Yakt::System->new->init(sub ($context) {
        my $actor = $context->spawn(Yakt::Props->new( class => 'RestartableActor' ));
        $actor->send(TriggerRestart->new);
    });

    $sys->loop_until_done;

    is($RestartableActor::STARTED_COUNT, 3, '... Started received 3 times (initial + 2 restarts)');
    is($RestartableActor::RESTARTING_COUNT, 2, '... Restarting received twice');
    is($RestartableActor::MESSAGE_COUNT, 3, '... messages processed 3 times');
};

done_testing;
