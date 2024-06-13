#!perl

use v5.40;
use experimental qw[ class ];

class Yakt::Streams::Subscribe {
    field $subscriber :param;
    method subscriber { $subscriber }
}
