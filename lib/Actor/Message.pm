#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

class Actor::Message {
    field $from :param;
    field $body :param;

    method from { $from }
    method body { $body }
}
