#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

class Actor::Behavior {
    method receive ($context, $message) {}
    method signal  ($context, $signal ) {}
}
