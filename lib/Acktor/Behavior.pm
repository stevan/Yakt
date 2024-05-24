#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

class Acktor::Behavior {
    method receive_message ($actor, $context, $message) {
        say "<<< Behavior->receive_message(actor($actor), context($context), message($message))";
        $actor->apply($context, $message);
    }

    method receive_signal  ($actor, $context, $signal)  {
        say "<<< Behavior->receive_signal(actor($actor), context($context), signal($signal))";
        $actor->apply($context, $signal);
    }
}
