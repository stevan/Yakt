#!perl

use v5.40;
use experimental qw[ class ];

use Yakt::System::Signals;

# TODO - move to a Yakt::Messages:: or something
class Yakt::System::Actors::DeadLetterQueue::DeadLetter {
    use overload '""' => \&to_string;
    field $to      :param;
    field $message :param;
    method to      { $to      }
    method message { $message }
    method to_string { sprintf '%s (%s)' => $to, $message }
}

class Yakt::System::Actors::DeadLetterQueue :isa(Yakt::Actor) {
    use Yakt::Logging;

    field @dead_letters;

    method dead_letters { @dead_letters }

    method receive ($context, $message) {
        $context->logger->log(WARN, "Got Dead Letter ($message)" ) if WARN;
        push @dead_letters => $message;
        return true;
    }

    method signal ($context, $signal) {
        if ($signal isa Yakt::System::Signals::Started) {
            $context->logger->log(INTERNALS, sprintf 'Started %s notifying parent(%s)' => $context->self, $context->parent ) if INTERNALS;
            $context->parent->context->notify( Yakt::System::Signals::Ready->new( ref => $context->self ) );
        }
    }
}
