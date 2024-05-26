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
    }

    # Event handlers for Signals
    method post_start  ($context) { $self->logger->log( DEBUG, sprintf    'Started %s' => $context->self ) if DEBUG }
    method pre_stop    ($context) { $self->logger->log( DEBUG, sprintf   'Stopping %s' => $context->self ) if DEBUG }
    method pre_restart ($context) { $self->logger->log( DEBUG, sprintf 'Restarting %s' => $context->self ) if DEBUG }
    method post_stop   ($context) { $self->logger->log( DEBUG, sprintf    'Stopped %s' => $context->self ) if DEBUG }
}

