#!perl

use v5.40;
use experimental qw[ class ];

class Acktor::Streams::OnError {
    field $error :param;
    method error { $error }
}
