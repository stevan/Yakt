#!perl

use v5.40;
use experimental qw[ class ];

class Yakt::Message {
    use Yakt::Logging;

    use overload '""' => 'to_string';

    field $reply_to :param :reader = undef;
    field $sender   :param :reader = undef;
    field $payload  :param :reader = undef;

    method to_string {
        join '' => blessed $self, '(',
            ($reply_to ? "reply_to: $reply_to" : ()),
            ($sender   ? ", sender: $sender"   : ()),
            ($payload  ? ", payload: $payload" : ()),
        ')'
    }
}

