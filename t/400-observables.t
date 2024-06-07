#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Test::More;

use ok 'Acktor::System';

class Subscribe {
    use overload '""' => \&to_string;
    field $subscriber :param;
    method subscriber { $subscriber }
    method to_string { "Subscribe(${subscriber}"}
}

class OnNext {
    use overload '""' => \&to_string;
    field $value :param;
    method value { $value }
    method to_string { "OnNext(${value})" }
}

class OnCompleted {
    use overload '""' => \&to_string;
    method to_string { "OnCompleted()" }
}

class OnError {
    use overload '""' => \&to_string;
    field $error :param;
    method error { $error }
    method to_string { "OnError(${error})" }
}

class Observerable :isa(Acktor) {
    use Acktor::Logging;

    method subscribe :Receive(Subscribe) ($context, $message) {
        my $subscriber = $message->subscriber;

        foreach my $i ( 0, 1 ) {
            $subscriber->send( OnNext->new( value => $i ) );
        }

        $context->schedule( after => 0.2, callback => sub {
            foreach my $i ( 2, 3 ) {
                $subscriber->send( OnNext->new( value => $i ) );
            }

            $context->schedule( after => 0.1, callback => sub {
                foreach my $i ( 4, 5 ) {
                    $subscriber->send( OnNext->new( value => $i ) );
                }
            });
        });

        $context->schedule( after => 0.4, callback => sub {
            foreach my $i ( 6 .. 9 ) {
                $subscriber->send( OnNext->new( value => $i ) );
            }

            $context->schedule( after => 0.2, callback => sub {
                $subscriber->send( OnNext->new( value => 10 ) );
            });
        });

        $context->schedule( after => 0.8, callback => sub {
            $subscriber->send( OnCompleted->new );
            $context->stop;
        });
    }
}

class Observer :isa(Acktor) {
    use Acktor::Logging;

    our @RESULTS;
    our $COMPLETED = 0;
    our $ERROR;

    method on_next :Receive(OnNext) ($context, $message) {
        $context->logger->log(INFO, "OnNext called" ) if INFO;
        push @RESULTS => $message->value;
    }

    method on_completed :Receive(OnCompleted) ($context, $message) {
        $context->logger->log(INFO, "OnCompleted called" ) if INFO;
        $context->stop;
        $COMPLETED++;
    }

    method on_error :Receive(OnError) ($context, $message) {
        $context->logger->log(INFO, "OnError called" ) if INFO;
        $ERROR = $message->error;
    }
}

my $sys = Acktor::System->new->init(sub ($context) {
    my $observerable = $context->spawn( Acktor::Props->new( class => 'Observerable' ) );
    my $observer     = $context->spawn( Acktor::Props->new( class => 'Observer' ) );

    $observerable->send( Subscribe->new( subscriber => $observer ));
});

$sys->loop_until_done;

is($Observer::COMPLETED, 1, '... got the right completed number');
ok(!defined($Observer::ERROR), '... got no error');
is_deeply(\@Observer::RESULTS, [ 0 .. 10 ], '... got the expected results');

done_testing;

