#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Acktor;

class Acktor::System::Actors::Users :isa(Acktor) {
    use Acktor::Logging;

    field $init :param;

    field $logger;

    ADJUST {
        $logger = Acktor::Logging->logger(__PACKAGE__) if LOG_LEVEL;
    }

    method signal ($context, $signal) {
        if ($signal isa Acktor::System::Signals::Started) {
            $logger->log(INTERNALS, sprintf 'Started %s' => $context->self ) if INTERNALS;
            try {
                $logger->log(INTERNALS, "Running init callback for $context" ) if INTERNALS;
                $init->($context);
            } catch ($e) {
                $logger->log(ERROR, "!!!!!! Error running init callback for $context with ($e)" ) if ERROR;
            }
        }
    }
}
