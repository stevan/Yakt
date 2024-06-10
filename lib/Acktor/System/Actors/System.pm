#!perl

use v5.40;
use experimental qw[ class ];

use Acktor::Props;
use Acktor::System::Signals;
use Acktor::System::Actors::DeadLetterQueue;

class Acktor::System::Actors::System :isa(Acktor::Actor) {
    use Acktor::Logging;

    field $dead_letter_queue;

    method signal ($context, $signal) {
        my $logger = $context->logger;

        if ($signal isa Acktor::System::Signals::Started) {
            $logger->log(INTERNALS, sprintf 'Started %s' => $context->self ) if INTERNALS;
            $dead_letter_queue = $context->spawn( Acktor::Props->new(
                class => 'Acktor::System::Actors::DeadLetterQueue',
                alias => '//sys/dead_letters',
            ));
        }
        elsif ($signal isa Acktor::System::Signals::Ready) {
            if ( refaddr $signal->ref == refaddr $dead_letter_queue ) {
                $logger->log(INTERNALS, sprintf 'DeadLetter Queue Started for(%s) notifying parent(%s)' => $context->self, $context->parent ) if INTERNALS;
                $context->parent->context->notify( Acktor::System::Signals::Ready->new( ref => $context->self ) );
            }
        }
    }
}
