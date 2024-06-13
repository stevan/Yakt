#!perl

use v5.40;
use experimental qw[ class ];

use Yakt::System::Signals;

class Yakt::System::Actors::Users :isa(Yakt::Actor) {
    use Yakt::Logging;

    method signal ($context, $signal) {
        my $logger = $context->logger;

        if ($signal isa Yakt::System::Signals::Started) {
            $logger->log(INTERNALS, sprintf 'Started %s notifying parent(%s)' => $context->self, $context->parent ) if INTERNALS;
            $context->parent->context->notify( Yakt::System::Signals::Ready->new( ref => $context->self ) );
        }
    }
}
