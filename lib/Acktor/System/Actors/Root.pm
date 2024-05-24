#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Acktor;
use Acktor::Props;
use Acktor::System::Actors::System;
use Acktor::System::Actors::Users;

class Acktor::System::Actors::Root :isa(Acktor) {
    field $init :param;

    method post_start  ($context) {
        say sprintf 'Started %s' => $context->self;

        $context->spawn( Acktor::Props->new(
            class => 'Acktor::System::Actors::System',
            alias => '//sys'
        ));
        $context->spawn( Acktor::Props->new(
            class => 'Acktor::System::Actors::Users',
            alias => '//usr',
            args  => { init => $init }
        ));
    }
}
