#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

class Acktor::Streams::OnError {
    field $error :param;
    method error { $error }
}
