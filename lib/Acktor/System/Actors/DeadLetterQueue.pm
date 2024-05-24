#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Acktor;

# TODO - move to a Acktor::Messages:: or something
class Acktor::System::Actors::DeadLetterQueue::DeadLetter {
    field $to      :param;
    field $message :param;
    method to      { $to      }
    method message { $message }
    method to_string { sprintf '%s(%03d) (%s)' => $to->context->props->class, $to->pid, "$message" }
}

class Acktor::System::Actors::DeadLetterQueue :isa(Acktor) {
    field @dead_letters;

    method dead_letters { @dead_letters }

    method apply ($context, $message) {
        push @dead_letters => Acktor::System::Actors::DeadLetterQueue::DeadLetter->new(
            to      => $context->self,
            message => $message
        );
        say "*** DEAD LETTER(".$dead_letters[-1].") ***";
    }
}
