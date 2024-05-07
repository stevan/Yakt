#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

class Actor::Behavior {

    field $receivers :param = +{};
    field $signals   :param = +{};

    method receive ($actor, $context, $message) {
        my $receiver = $receivers->{ blessed $message };
        return false unless $receiver;
        $actor->$receiver( $context, $message );
        return true;
    }

    method signal ($actor, $context,  $signal) {
        my $handler = $signals->{ blessed $signal };
        return false unless $handler;
        $actor->$handler( $context, $signal );
        return true;
    }
}
