#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Acktor;

class Acktor::System::Actors::Users :isa(Acktor) {
    field $init :param;

    method post_start  ($context) {
        say sprintf 'Started %s' => $context->self;
        try {
            say "Running init callback for $context";
            $init->($context);
        } catch ($e) {
            say "!!!!!! Error running init callback for $context with ($e)";
        }
    }
}
