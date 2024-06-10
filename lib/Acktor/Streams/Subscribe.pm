#!perl

use v5.40;
use experimental qw[ class ];

class Acktor::Streams::Subscribe {
    field $subscriber :param;
    method subscriber { $subscriber }
}
