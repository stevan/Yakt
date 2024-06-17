#!perl

use v5.40;
use experimental qw[ class ];

class Yakt::Streams::Unsubscribe :isa(Yakt::Message) {
    field $subscriber :param;
    method subscriber { $subscriber }
}
