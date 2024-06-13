#!perl

use v5.40;
use experimental qw[ class ];

class Yakt::Streams::OnNext {
    field $value :param;
    method value { $value }
}
