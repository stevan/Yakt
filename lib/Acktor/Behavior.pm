#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

class Acktor::Behavior {
    use Acktor::Logging;

    field $logger;

    ADJUST {
        $logger = Acktor::Logging->logger(__PACKAGE__) if LOG_LEVEL;
    }

    method receive_message ($actor, $context, $message) {
        $logger->log(INTERNALS, sprintf "Received ! Message($message) for ".$context->self ) if INTERNALS;
        $actor->apply($context, $message);
    }

    method receive_signal  ($actor, $context, $signal)  {
        $logger->log(INTERNALS, sprintf "Received ! Signal($signal) for ".$context->self ) if INTERNALS;
        $actor->signal($context, $signal);
    }
}
