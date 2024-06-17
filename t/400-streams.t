#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::System';

use Yakt::Logging;
use Yakt::Streams;
use Yakt::Streams::Actors::Observer;

class Observerable :isa(Yakt::Actor) {
    use Yakt::Logging;

    method subscribe :Receive(Yakt::Streams::Subscribe) ($context, $message) {
        my $subscriber = $message->subscriber;

        foreach my $i ( 0, 1 ) {
            $subscriber->send( Yakt::Streams::OnNext->new( value => $i ) );
        }

        $context->schedule( after => 0.2, callback => sub {
            foreach my $i ( 2, 3 ) {
                $subscriber->send( Yakt::Streams::OnNext->new( value => $i ) );
            }

            $context->schedule( after => 0.1, callback => sub {
                foreach my $i ( 4, 5 ) {
                    $subscriber->send( Yakt::Streams::OnNext->new( value => $i ) );
                }
            });
        });

        $context->schedule( after => 0.4, callback => sub {
            foreach my $i ( 6 .. 9 ) {
                $subscriber->send( Yakt::Streams::OnNext->new( value => $i ) );
            }

            $context->schedule( after => 0.2, callback => sub {
                $subscriber->send( Yakt::Streams::OnNext->new( value => 10 ) );
            });
        });

        $context->schedule( after => 0.8, callback => sub {
            $subscriber->send( Yakt::Streams::OnCompleted->new );
            $context->stop;
        });
    }
}

our @RESULTS;
our $COMPLETED = 0;
our $ERROR;

my $sys = Yakt::System->new->init(sub ($context) {
    my $observerable = $context->spawn( Yakt::Props->new( class => 'Observerable' ) );
    my $observer     = $context->spawn( Yakt::Props->new(
        class => 'Yakt::Streams::Actors::Observer',
        args  => {
            on_next => sub ($context, $message) {
                $context->logger->log(INFO, "->OnNext called" ) if INFO;
                push @RESULTS => $message->value;
            },
            on_completed => sub ($context, $message) {
                $context->logger->log(INFO, "->OnCompleted called" ) if INFO;
                $context->stop;
                $COMPLETED++;
            },
            on_error => sub ($context, $message) {
                $context->logger->log(INFO, "->OnError called" ) if INFO;
                $ERROR = $message->error;
            }
        }
    ));

    $observerable->send( Yakt::Streams::Subscribe->new( subscriber => $observer ));
});

$sys->loop_until_done;

is($COMPLETED, 1, '... got the right completed number');
ok(!defined($ERROR), '... got no error');
is_deeply(\@RESULTS, [ 0 .. 10 ], '... got the expected results');

done_testing;

