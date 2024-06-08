#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

class Acktor::Message {
    use Acktor::Logging;

    use overload '""' => 'to_string';

    field $reply_to :param = undef;
    field $sender   :param = undef;

    method reply_to { $reply_to }
    method sender   { $sender   }

    method to_string {
        join '' => blessed $self, '(',
            ($reply_to ? "reply_to: $reply_to" : ()),
            ($sender   ? "sender: $sender"     : ()),
        ')'
    }
}

