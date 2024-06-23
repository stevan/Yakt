#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::System';

use Yakt::Streams;

class Source {
    field $source :param;
    method next { shift @$source }
}

class MyObserver :isa(Yakt::Streams::Actors::Observer) {
    use Yakt::Logging;

    our @RESULTS;
    our $COMPLETED = 0;
    our $ERROR;

    method on_next ($context, $message) {
        $context->logger->log(INFO, "->OnNext called" ) if INFO;
        push @RESULTS => $message->value;
    }

    method on_completed ($context, $message) {
        $context->logger->log(INFO, "->OnCompleted called" ) if INFO;
        $message->sender->send( Yakt::Streams::Unsubscribe->new( subscriber => $context->self ) );
        $COMPLETED++;
    }

    method on_error ($context, $message) {
        $context->logger->log(INFO, "->OnError called" ) if INFO;
        $ERROR = $message->error;
    }

    method on_unsubscribe ($context, $message) {
        $context->logger->log(INFO, "->OnUnsubscribe called" ) if INFO;
        $context->stop;
    }

}

my $sys = Yakt::System->new->init(sub ($context) {
    Yakt::Streams::Composers::Flow->new
        ->from_source( Source->new( source => [ 0 .. 10 ] ) )
        #->from_callback( sub { state $i = 0; return $i <= 10 ? $i++ : undef } )
        ->map  ( sub ($x) { $x * 2 } )
        ->grep ( sub ($x) { ($x % 2) == 0 } )
        ->to   ( $context->spawn( Yakt::Props->new( class => 'MyObserver' )) )
        ->run  ( $context );
});

$sys->loop_until_done;

is($MyObserver::COMPLETED, 1, '... got the right completed number');
ok(!defined($MyObserver::ERROR), '... got no error');
is_deeply(\@MyObserver::RESULTS, [ grep { ($_ % 2) == 0 }  map $_*2, 0 .. 10 ], '... got the expected results');

done_testing;

