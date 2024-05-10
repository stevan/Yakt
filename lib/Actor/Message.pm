#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

class Actor::Message {
    use overload '""' => 'to_string';

    field $from     :param = undef;
    field $reply_to :param = undef;

    method from     { $from     }
    method reply_to { $reply_to }

    method to_string { blessed $self }
}
