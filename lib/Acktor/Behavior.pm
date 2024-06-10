#!perl

use v5.40;
use experimental qw[ class ];

class Acktor::Behavior {
    use Acktor::Logging;

    field $receivers :param = +{};
    field $handlers  :param = +{};

    field $logger;

    ADJUST {
        $logger = Acktor::Logging->logger(__PACKAGE__) if LOG_LEVEL;
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

