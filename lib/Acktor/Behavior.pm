#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

class Acktor::Behavior {
    use Acktor::Logging;

    field $receivers :param = +{};
    field $handlers  :param = +{};

    field $logger;

    ADJUST {
        $logger = Acktor::Logging->logger(__PACKAGE__) if LOG_LEVEL;
    }

    method receive_message ($actor, $context, $message) {
        $logger->log(INTERNALS, sprintf "Received ! Message($message) for ".$context->self ) if INTERNALS;
        if (my $method = $receivers->{ blessed $message }) {
            $actor->$method( $context, $message );
            return true;
        }
        else {
            return $actor->apply($context, $message);
        }
    }

    method receive_signal  ($actor, $context, $signal)  {
        $logger->log(INTERNALS, sprintf "Received ! Signal($signal) for ".$context->self ) if INTERNALS;
        if (my $method = $handlers->{ blessed $signal }) {
            $actor->$method( $context, $signal );
        } else {
            $actor->signal($context, $signal);
        }
    }
}

