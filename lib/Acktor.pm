#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

class Acktor {
    use Acktor::Logging;

    field $logger;

    ADJUST {
        $logger = Acktor::Logging->logger(blessed $self) if LOG_LEVEL;
    }

    method logger { $logger }

    method apply ($context, $message) {
        $self->logger->log( WARN, "Unhandled message! $context => $message" ) if WARN;
        return false;
    }

    method signal ($context, $message) {}
}

