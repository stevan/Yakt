#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

class Acktor::Streams::OnNext {
    field $value :param;
    method value { $value }
}
