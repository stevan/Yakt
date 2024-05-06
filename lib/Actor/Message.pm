#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

class Actor::Message {
    field $from     :param = undef;
    field $reply_to :param = undef;
    field $body     :param = undef;

    method from     { $from     }
    method reply_to { $reply_to }
    method body     { $body     }
}
