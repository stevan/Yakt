#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Acktor::Supervisors::Supervisor;

class Acktor::Supervisors::Stop :isa(Acktor::Supervisors::Supervisor) {
    method supervise ($context, $e) {
        say "!!! OH NOES, we got an error ($e) STOPPING";
        $context->stop;
        return $self->HALT;
    }
}
