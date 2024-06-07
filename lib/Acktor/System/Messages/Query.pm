#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Acktor::System::Messages::Message;

class Acktor::System::Messages::Query :isa(Acktor::System::Messages::Message) {
    field $reply_to :param;

    method reply_to { $reply_to }
}
