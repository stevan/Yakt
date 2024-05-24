#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Acktor;
use Acktor::Props;
use Acktor::System::Actors::DeadLetterQueue;

class Acktor::System::Actors::System :isa(Acktor) {
    method post_start  ($context) {
        say sprintf 'Started %s' => $context->self;
        $context->spawn( Acktor::Props->new(
            class => 'Acktor::System::Actors::DeadLetterQueue',
            alias => '//sys/dead_letters',
        ));
    }
}
