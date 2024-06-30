#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::System';

use Yakt::Streams;

use Yakt::IO::Actors::StreamReader;
use Yakt::Streams::Actors::Operator::Map;

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
        $context->logger->log(INFO, (join "\n" => @RESULTS) ) if INFO;
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

class MySingleObserver :isa(Yakt::Streams::Actors::Observer::Single) {
    use Yakt::Logging;

    our $SUCCESS;
    our $ERROR;

    method on_success ($context, $message) {
        $context->logger->log(INFO, "->OnSuccess called" ) if INFO;
        $SUCCESS++;
        $context->stop;
    }

    method on_error ($context, $message) {
        $context->logger->log(INFO, "->OnError called with error: ".$message->error ) if INFO;
        $ERROR++;
        $context->stop;
    }
}

my $sys = Yakt::System->new->init(sub ($context) {

    Yakt::Streams::Composers::Flow->new
        ->from(Yakt::Props->new( class => Yakt::IO::Actors::StreamReader::, args => { path => __FILE__ }))
        ->map( sub ($line) {
            state $line_no = 0;
            sprintf '%4d : %s', ++$line_no, $line
        })
        ->to(Yakt::Props->new( class => MyObserver:: ))
        ->spawn( $context )
        ->send(
            Yakt::Streams::Subscribe->new(
                subscriber => $context->spawn( Yakt::Props->new(class => MySingleObserver::))
            )
        );
});

$sys->loop_until_done;

like($MyObserver::RESULTS[-1], qr/# THE END$/, '... got the expected last line for fh');

is($MySingleObserver::SUCCESS, 1, '... got the right success number');
ok(!defined($MySingleObserver::ERROR), '... got no error');

done_testing;

# THE END
