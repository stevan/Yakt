#!perl

use v5.40;
use experimental qw[ class ];

use Acktor;
use Acktor::System::Signals;

class Acktor::System::Actors::Users :isa(Acktor) {
    use Acktor::Logging;

    method signal ($context, $signal) {
        my $logger = $context->logger;

        if ($signal isa Acktor::System::Signals::Started) {
            $logger->log(INTERNALS, sprintf 'Started %s notifying parent(%s)' => $context->self, $context->parent ) if INTERNALS;
            $context->parent->context->notify( Acktor::System::Signals::Ready->new( ref => $context->self ) );
        }
    }
}
