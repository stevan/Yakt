#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::System';

use Yakt::Logging;
use Yakt::Streams;
use Yakt::Streams::Actors::Observer;
use Yakt::Streams::Actors::Observable::FromSource;
use Yakt::Streams::Actors::Operator::Map;

class Source {
    field $source :param;
    method next { shift @$source }
}

our @RESULTS;
our $COMPLETED = 0;
our $ERROR;

my $sys = Yakt::System->new->init(sub ($context) {

    my $observerable = $context->spawn( Yakt::Props->new(
        class => 'Yakt::Streams::Actors::Observable::FromSource',
        args  => {
            source => Source->new( source => [ 0 .. 10 ] )
        }
    ));

    my $map = $context->spawn( Yakt::Props->new(
        class => 'Yakt::Streams::Actors::Operator::Map',
        args  => {
            f => sub ($x) { $x * 2 }
        }
    ));

    my $observer = $context->spawn( Yakt::Props->new(
        class => 'Yakt::Streams::Actors::Observer',
        args  => {
            on_next => sub ($context, $message) {
                $context->logger->log(INFO, "->OnNext called" ) if INFO;
                push @RESULTS => $message->value;
            },
            on_completed => sub ($context, $message) {
                $context->logger->log(INFO, "->OnCompleted called" ) if INFO;
                $message->sender->send( Yakt::Streams::Unsubscribe->new( subscriber => $context->self ) );
                $COMPLETED++;
            },
            on_error => sub ($context, $message) {
                $context->logger->log(INFO, "->OnError called" ) if INFO;
                $ERROR = $message->error;
            },
            on_unsubscribe => sub ($context, $message) {
                $context->logger->log(INFO, "->OnUnsubscribe called" ) if INFO;
                $context->stop;
            }
        }
    ));

    $observerable->send( Yakt::Streams::Subscribe->new( subscriber => $map ));

    $map->send( Yakt::Streams::Subscribe->new( subscriber => $observer ));
});

$sys->loop_until_done;

is($COMPLETED, 1, '... got the right completed number');
ok(!defined($ERROR), '... got no error');
is_deeply(\@RESULTS, [ map $_*2, 0 .. 10 ], '... got the expected results');

done_testing;

