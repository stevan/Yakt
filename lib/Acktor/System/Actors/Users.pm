#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Acktor;
use Acktor::System::Signals;

class Acktor::System::Actors::Users :isa(Acktor) {
    use Acktor::Logging;

    field $logger;

    ADJUST {
        $logger = Acktor::Logging->logger(__PACKAGE__) if LOG_LEVEL;
    }

    method signal ($context, $signal) {
        if ($signal isa Acktor::System::Signals::Started) {
            $logger->log(INTERNALS, sprintf 'Started %s notifying parent(%s)' => $context->self, $context->parent ) if INTERNALS;
            $context->parent->context->notify( Acktor::System::Signals::Ready->new( ref => $context->self ) );
        }
    }
}
