#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Test::More;

use Acktor::System;

class Bar {}

class Foo :isa(Acktor) {
    use Acktor::Logging;

    field $depth :param = 1;
    field $max   :param = 4;

    my $RESTARTS = 0;

    method apply ($context, $message) {
        $self->logger->log(INFO, "HELLO JOE! => { Actor($self) got $context and message($message) }" ) if INFO;
        if ($message isa Bar) {
            $RESTARTS++;
            die "Going to Restart!"
        }
    }

    method post_start  ($context) {
        $self->logger->log(INFO, sprintf 'Started %s' => $context->self ) if INFO;
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
            if ($RESTARTS) {
                $x->context->stop;
            }
            else {
                $x->send( Bar->new );
            }
        }
    }

    method pre_stop    ($context) { $self->logger->log( INFO, sprintf   'Stopping %s' => $context->self ) if INFO }
    method pre_restart ($context) { $self->logger->log( INFO, sprintf 'Restarting %s' => $context->self ) if INFO }
    method post_stop   ($context) { $self->logger->log( INFO, sprintf    'Stopped %s' => $context->self ) if INFO }
}

my $sys = Acktor::System->new->init(sub ($context) {
    $context->spawn( Acktor::Props->new( class => 'Foo' ) );
});


$sys->loop_until_done;

