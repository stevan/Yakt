#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];


class Acktor::Ref {
    use overload '""' => \&to_string;

    field $pid :param;

    field $context;

    method set_context ($c) { $context = $c; $self }
    method context { $context }

    method pid { $pid }

    method send ($message) {
        say "> Ref($self)::send($message)";
        $context->send_message( $self, $message );
    }

    method to_string {
        sprintf '<%s>[%03d]' => $context->props->class, $pid;
    }
}
