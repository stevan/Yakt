#!perl

use v5.40;
use experimental qw[ class ];

class Yakt::Streams::OnNext :isa(Yakt::Message) {
    field $value :param;
    method value { $value }
}
