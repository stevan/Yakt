#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

class Acktor::System::Messages::Message {
    field $sender :param = undef;

    method get_sender {    $sender }
    method has_sender { !! $sender }
}

