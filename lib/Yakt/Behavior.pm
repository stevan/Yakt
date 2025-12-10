#!perl

use v5.40;
use experimental qw[ class ];

class Yakt::Behavior {
    use Yakt::Logging;

    field $receivers :param = +{};
    field $handlers  :param = +{};

    field $logger;

    ADJUST {
        $logger = Yakt::Logging->logger(__PACKAGE__) if LOG_LEVEL;
    }

    method receive_message ($actor, $context, $message) {
        $logger->log(INTERNALS, "Received ! Message($message) for ".$context->self ) if INTERNALS;
        my $method = $receivers->{ blessed $message } // return false;
        $actor->$method( $context, $message );
        return true;
    }

    method receive_signal  ($actor, $context, $signal)  {
        $logger->log(INTERNALS, "Received ! Signal($signal) for ".$context->self ) if INTERNALS;
        my $method = $handlers->{ blessed $signal } // return false;
        $actor->$method( $context, $signal );
        return true;
    }
}

__END__

=pod

=encoding UTF-8

=head1 NAME

Yakt::Behavior - Message and signal routing for actors

=head1 SYNOPSIS

    # Behaviors are typically created automatically via @Receive/@Signal attributes
    class MyActor :isa(Yakt::Actor) {
        method on_foo :Receive(Foo) ($context, $message) { ... }
        method on_bar :Receive(Bar) ($context, $message) { ... }
    }

    # Manual behavior creation (advanced)
    my $behavior = Yakt::Behavior->new(
        receivers => {
            'Foo' => \&handle_foo,
            'Bar' => \&handle_bar,
        },
        handlers => {
            'Yakt::System::Signals::Started' => \&on_started,
        }
    );

=head1 DESCRIPTION

C<Yakt::Behavior> handles message and signal routing for actors. It maintains
dispatch tables mapping message/signal types to handler methods.

Most users won't interact with Behavior directly - it's created automatically
from the C<@Receive> and C<@Signal> attributes on actor methods.

=head1 STATUS

B<Internal/Advanced> - Works correctly but direct usage is uncommon.
See L</FUTURE WORK> for planned improvements.

=head1 CONSTRUCTOR

=head2 new(%options)

    my $behavior = Yakt::Behavior->new(
        receivers => \%message_handlers,  # optional
        handlers  => \%signal_handlers,   # optional
    );

=over 4

=item receivers

Hash mapping message class names to method references.

=item handlers

Hash mapping signal class names to method references.

=back

=head1 METHODS

=head2 receive_message($actor, $context, $message)

    my $handled = $behavior->receive_message($actor, $context, $message);

Dispatches a message to the appropriate handler. Returns true if handled,
false if no handler found (message goes to dead letter queue).

=head2 receive_signal($actor, $context, $signal)

    my $handled = $behavior->receive_signal($actor, $context, $signal);

Dispatches a signal to the appropriate handler. Returns true if handled,
false if no handler found (signal is ignored).

=head1 BEHAVIOR SWITCHING

Actors can switch behaviors dynamically using C<become>/C<unbecome>:

    class StatefulActor :isa(Yakt::Actor) {
        method on_start :Receive(Start) ($context, $message) {
            $self->become($self->active_behavior);
        }

        method active_behavior {
            # Return a Behavior object
        }
    }

The behavior stack allows FSM-style patterns:

    Initial -> become(A) -> become(B) -> unbecome -> back to A

=head1 FUTURE WORK

=over 4

=item * Helper function for creating Behaviors without a class

    my $behavior = behaviors(
        Foo => sub ($context, $message) { ... },
        Bar => sub ($context, $message) { ... },
    );

=item * Better integration with C<become>/C<unbecome>

=back

=head1 SEE ALSO

L<Yakt::Actor>

=cut
