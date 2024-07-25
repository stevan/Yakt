#!perl

use v5.40;
use experimental qw[ class ];

use Yakt::Props;
use Yakt::System::Signals;
use Yakt::System::Actors::DeadLetterQueue;

class Yakt::System::Actors::System :isa(Yakt::Actor) {
    use Yakt::Logging;

    field $dead_letter_queue;

    method signal ($context, $signal) {
        my $logger;
        $logger = $context->logger if DEBUG;

        if ($signal isa Yakt::System::Signals::Started) {
            $logger->log(INTERNALS, sprintf 'Started %s' => $context->self ) if INTERNALS;
            $dead_letter_queue = $context->spawn( Yakt::Props->new(
                class => 'Yakt::System::Actors::DeadLetterQueue',
                alias => '//sys/dead_letters',
            ));
        }
        elsif ($signal isa Yakt::System::Signals::Ready) {
            if ( refaddr $signal->ref == refaddr $dead_letter_queue ) {
                $logger->log(INTERNALS, sprintf 'DeadLetter Queue Started for(%s) notifying parent(%s)' => $context->self, $context->parent ) if INTERNALS;
                $context->parent->context->notify( Yakt::System::Signals::Ready->new( ref => $context->self ) );
            }
        }
    }
}
