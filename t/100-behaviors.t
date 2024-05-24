#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Test::More;

use Acktor::System;

class Bar {}

class Foo :isa(Acktor) {
    field $depth :param = 1;
    field $max   :param = 4;

    method apply ($context, $message) {
        say "HELLO JOE! => { Actor($self) got $context and message($message) }";
    }

    method post_start  ($context) {
        say sprintf 'Started    %s' => $context->self;
        if ( $depth <= $max ) {
            $context->spawn(Acktor::Props->new(
                class => 'Foo',
                args => {
                    depth => $depth + 1,
                    max   => $max
                }
            ));
        }
        else {
            # find the topmost Foo
            my $x = $context->self;
            do {
                $x = $x->context->parent;
            } while $x->context->parent
                 && $x->context->parent->context->props->class eq 'Foo';

            # and stop it
            $x->context->stop;
        }
    }

    method pre_stop    ($context) { say sprintf 'Stopping   %s' => $context->self }
    method pre_restart ($context) { say sprintf 'Restarting %s' => $context->self }
    method post_stop   ($context) { say sprintf 'Stopped    %s' => $context->self }
}

my $sys = Acktor::System->new->init(sub ($context) {
    $context->spawn( Acktor::Props->new( class => 'Foo' ) );
});


$sys->loop_until_done;

