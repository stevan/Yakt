#!perl

use v5.40;
use experimental qw[ class ];

class Yakt::Streams::OnError :isa(Yakt::Message) {
    field $error :param;
    method error { $error }
}
