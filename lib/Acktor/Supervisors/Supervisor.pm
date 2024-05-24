#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

class Acktor::Supervisors::Supervisor {
    use constant RESUME => 1;
    use constant RETRY  => 2;
    use constant HALT   => 3;

    method supervise ($context, $e) {
        say "!!! OH NOES, we got an error ($e)";
    }
}
