#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Acktor::System';

use Acktor::Streams;

class Observerable :isa(Acktor) {
    use Acktor::Logging;

    method subscribe :Receive(Acktor::Streams::Subscribe) ($context, $message) {
        my $subscriber = $message->subscriber;

        foreach my $i ( 0, 1 ) {
            $subscriber->send( Acktor::Streams::OnNext->new( value => $i ) );
        }

        $context->schedule( after => 0.2, callback => sub {
            foreach my $i ( 2, 3 ) {
                $subscriber->send( Acktor::Streams::OnNext->new( value => $i ) );
            }

            $context->schedule( after => 0.1, callback => sub {
                foreach my $i ( 4, 5 ) {
                    $subscriber->send( Acktor::Streams::OnNext->new( value => $i ) );
                }
            });
        });

        $context->schedule( after => 0.4, callback => sub {
            foreach my $i ( 6 .. 9 ) {
                $subscriber->send( Acktor::Streams::OnNext->new( value => $i ) );
            }

            $context->schedule( after => 0.2, callback => sub {
                $subscriber->send( Acktor::Streams::OnNext->new( value => 10 ) );
            });
        });

        $context->schedule( after => 0.8, callback => sub {
            $subscriber->send( Acktor::Streams::OnCompleted->new );
            $context->stop;
        });
    }
}

class Observer :isa(Acktor) {
    use Acktor::Logging;

    our @RESULTS;
    our $COMPLETED = 0;
    our $ERROR;

    method on_next :Receive(Acktor::Streams::OnNext) ($context, $message) {
        $context->logger->log(INFO, "OnNext called" ) if INFO;
        push @RESULTS => $message->value;
    }

    method on_completed :Receive(Acktor::Streams::OnCompleted) ($context, $message) {
        $context->logger->log(INFO, "OnCompleted called" ) if INFO;
        $context->stop;
        $COMPLETED++;
    }

    method on_error :Receive(Acktor::Streams::OnError) ($context, $message) {
        $context->logger->log(INFO, "OnError called" ) if INFO;
        $ERROR = $message->error;
    }
}

my $sys = Acktor::System->new->init(sub ($context) {
    my $observerable = $context->spawn( Acktor::Props->new( class => 'Observerable' ) );
    my $observer     = $context->spawn( Acktor::Props->new( class => 'Observer' ) );

    $observerable->send( Acktor::Streams::Subscribe->new( subscriber => $observer ));
});

$sys->loop_until_done;

is($Observer::COMPLETED, 1, '... got the right completed number');
ok(!defined($Observer::ERROR), '... got no error');
is_deeply(\@Observer::RESULTS, [ 0 .. 10 ], '... got the expected results');

done_testing;

