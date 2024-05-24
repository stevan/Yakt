#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];



class Acktor::Supervisors::Supervisor {
    method supervise ($mailbox, $e) {
        say "!!! OH NOES, we got an error ($e)";
    }
}
