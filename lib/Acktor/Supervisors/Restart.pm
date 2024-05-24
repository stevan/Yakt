#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Acktor::Supervisors::Supervisor;

class Acktor::Supervisors::Restart :isa(Acktor::Supervisors::Supervisor) {
    method supervise ($context, $e) {
        say "!!! OH NOES, we got an error ($e) RESTARTING";
        $context->restart;
        return $self->HALT;
    }
}
