#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Acktor::System::Messages::Message;

class Acktor::System::Messages::Command :isa(Acktor::System::Messages::Message) {
    field $sender :param = undef;

    method get_sender {    $sender }
    method has_sender { !! $sender }
}
