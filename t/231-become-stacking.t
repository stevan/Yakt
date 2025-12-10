#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::System';

class Msg :isa(Yakt::Message) { field $n :param :reader; }
class Done :isa(Yakt::Message) {}

# Actor that stacks multiple behaviors
class StackingActor :isa(Yakt::Actor) {
    use Yakt::Logging;

    our @EVENTS;

    method on_start :Signal(Yakt::System::Signals::Started) ($context, $signal) {
        push @EVENTS => 'base';
    }

    method handle :Receive(Msg) ($context, $message) {
        my $n = $message->n;
        push @EVENTS => "base:$n";

        if ($n == 1) {
            # Stack first behavior
            $self->become($self->make_behavior('first'));
        }
    }

    method done :Receive(Done) ($context, $message) {
        push @EVENTS => 'base:done';
        $context->stop;
    }

    method make_behavior ($name) {
        my $actor = $self;
        Yakt::Behavior->new(
            receivers => {
                'Msg'  => sub ($self, $ctx, $msg) {
                    my $n = $msg->n;
                    push @EVENTS => "$name:$n";
                    if ($n == 2) {
                        # Stack another behavior
                        $actor->become($actor->make_behavior('second'));
                    } elsif ($n == 4) {
                        # Pop back to previous
                        $actor->unbecome;
                    }
                },
                'Done' => sub ($self, $ctx, $msg) {
                    push @EVENTS => "$name:done";
                    $actor->unbecome;
                },
            }
        );
    }
}

@StackingActor::EVENTS = ();

my $sys = Yakt::System->new->init(sub ($context) {
    my $actor = $context->spawn( Yakt::Props->new( class => 'StackingActor' ) );

    $actor->send(Msg->new( n => 0 ));  # base handles
    $actor->send(Msg->new( n => 1 ));  # base handles, becomes 'first'
    $actor->send(Msg->new( n => 2 ));  # first handles, becomes 'second'
    $actor->send(Msg->new( n => 3 ));  # second handles
    $actor->send(Msg->new( n => 4 ));  # second handles, unbecome -> first
    $actor->send(Msg->new( n => 5 ));  # first handles
    $actor->send(Done->new);           # first handles, unbecome -> base
    $actor->send(Done->new);           # base handles, stops
});

$sys->loop_until_done;

is_deeply(\@StackingActor::EVENTS, [
    'base',
    'base:0',
    'base:1',
    'first:2',
    'second:3',
    'second:4',
    'first:5',
    'first:done',
    'base:done',
], '... behavior stacking works correctly');

done_testing;
