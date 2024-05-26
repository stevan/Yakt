#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Test::More;

use ok 'Acktor::System';

class Hello {
    field $count = 0;

    method count { $count++; $self }
    method total { $count }
}

class Joe :isa(Acktor) {
    use Acktor::Logging;

    our $MESSAGED    = 0;
    our $STARTED     = 0;
    our $RESTARTED   = 0;
    our $STOPPING    = 0;
    our $STOPPED     = 0;
    our $TOTAL_HELLO = 0;

    method apply ($context, $message) {
        $MESSAGED++;
        $self->logger->log(INFO, "HELLO JOE! => { Actor($self) got $context and message($message) }" ) if INFO;
        $self->logger->log(INFO, "HELLO JOE! called ". $message->total ." times") if INFO;
        if ($RESTARTED < 5) {
            $context->self->send($message->count);
            die 'OH NOES!';
        }
        else {
            $self->logger->log(INFO, "Final! called ". $message->total ." times") if INFO;
            $TOTAL_HELLO = $message->total;
            $context->stop;
        }
    }

    method post_start ($context) {
        $STARTED++;
        $self->logger->log(INFO, sprintf 'Started %s' => $context->self ) if INFO;
    }

    method pre_stop ($context) {
        $STOPPING++;
        $self->logger->log( INFO, sprintf   'Stopping %s' => $context->self ) if INFO
    }

    method pre_restart ($context) {
        $RESTARTED++;
        $self->logger->log( INFO, sprintf 'Restarting %s' => $context->self ) if INFO
    }

    method post_stop ($context) {
        $STOPPED++;
        $self->logger->log( INFO, sprintf    'Stopped %s' => $context->self ) if INFO
    }
}

my $sys = Acktor::System->new->init(sub ($context) {
    my $joe = $context->spawn( Acktor::Props->new( class => 'Joe' ) );
    $joe->send(Hello->new);
});

$sys->loop_until_done;

is($Joe::MESSAGED,    6, '... got the expected messaged');
is($Joe::RESTARTED,   5, '... got the expected restarted');
is($Joe::STARTED,     6, '... got the expected started');
is($Joe::STOPPING,    1, '... got the expected stopping');
is($Joe::STOPPED,     1, '... got the expected stopped');
is($Joe::TOTAL_HELLO, 5, '... got the expected Hello->total');

done_testing;
