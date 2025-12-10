#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::System';

# Test messages
class ModeA :isa(Yakt::Message) {}
class ModeB :isa(Yakt::Message) {}
class Reset :isa(Yakt::Message) {}

# Actor that switches behaviors
class StateSwitcher :isa(Yakt::Actor) {
    use Yakt::Logging;

    our @EVENTS;

    method on_start :Signal(Yakt::System::Signals::Started) ($context, $signal) {
        push @EVENTS => 'started:normal';
    }

    method mode_a :Receive(ModeA) ($context, $message) {
        push @EVENTS => 'normal:mode_a';
        # Switch to "alternate mode"
        $self->become( $self->alternate_behavior );
    }

    method reset :Receive(Reset) ($context, $message) {
        push @EVENTS => 'normal:reset';
        $context->stop;
    }

    # Alternate behavior
    method alternate_behavior {
        Yakt::Behavior->new(
            receivers => {
                'ModeB' => $self->can('mode_b'),
                'Reset' => $self->can('back_to_normal'),
            }
        );
    }

    method mode_b ($context, $message) {
        push @EVENTS => 'alternate:mode_b';
    }

    method back_to_normal ($context, $message) {
        push @EVENTS => 'alternate:reset';
        $self->unbecome;
        # Now back in normal mode - send ourselves a reset to stop
        $context->self->send(Reset->new);
    }
}

# Test: become switches behavior, unbecome restores it
@StateSwitcher::EVENTS = ();

my $sys = Yakt::System->new->init(sub ($context) {
    my $switcher = $context->spawn( Yakt::Props->new( class => 'StateSwitcher' ) );

    # Start in normal mode
    $switcher->send(ModeA->new);  # -> becomes alternate mode
    # Now in alternate mode
    $switcher->send(ModeB->new);  # -> handled by alternate mode
    $switcher->send(Reset->new);  # -> back_to_normal, unbecome, sends Reset
    # Reset is processed in normal mode
});

$sys->loop_until_done;

is_deeply(\@StateSwitcher::EVENTS, [
    'started:normal',
    'normal:mode_a',
    'alternate:mode_b',
    'alternate:reset',
    'normal:reset',
], '... behavior switching works correctly');

done_testing;
