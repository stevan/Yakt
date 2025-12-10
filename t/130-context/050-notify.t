#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::System';

# Custom signal for testing notify
class CustomSignal :isa(Yakt::System::Signals::Signal) {
    field $data :param;
    method data { $data }
}

class SendSignal :isa(Yakt::Message) {}

class SignalReceiver :isa(Yakt::Actor) {
    our $CUSTOM_SIGNAL_DATA;

    method on_custom :Signal(CustomSignal) ($context, $signal) {
        $CUSTOM_SIGNAL_DATA = $signal->data;
        $context->stop;
    }
}

class SignalSender :isa(Yakt::Actor) {
    field $target :param;

    method on_send :Receive(SendSignal) ($context, $message) {
        $target->context->notify(CustomSignal->new( data => 'hello' ));
        $context->stop;
    }
}

subtest 'notify delivers signal to actor' => sub {
    $SignalReceiver::CUSTOM_SIGNAL_DATA = undef;

    my $sys = Yakt::System->new->init(sub ($context) {
        my $receiver = $context->spawn(Yakt::Props->new( class => 'SignalReceiver' ));
        my $sender = $context->spawn(Yakt::Props->new(
            class => 'SignalSender',
            args  => { target => $receiver }
        ));
        $sender->send(SendSignal->new);
    });

    $sys->loop_until_done;

    is($SignalReceiver::CUSTOM_SIGNAL_DATA, 'hello', '... custom signal was delivered');
};

done_testing;
