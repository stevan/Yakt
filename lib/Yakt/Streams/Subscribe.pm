#!perl

use v5.40;
use experimental qw[ class ];

class Yakt::Streams::Subscribe :isa(Yakt::Message) {
    field $subscriber :param;
    method subscriber { $subscriber }
}
