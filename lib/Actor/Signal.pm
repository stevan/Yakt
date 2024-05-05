#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

class Actor::Signal {
    field $body :param = undef;

    method body { $body }
}
