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

my $sys = Yakt::System->new->init(sub ($context) {

    my $fh = IO::File->new;
    $fh->open(__FILE__, 'r');

    my $input  = $context->spawn( Yakt::Props->new( class => Yakt::IO::Actors::StreamReader::, args => { fh => $fh }));
    my $output = $context->spawn( Yakt::Props->new( class => MyObserver:: ));

    my $map = $context->spawn( Yakt::Props->new( class => Yakt::Streams::Actors::Operator::Map::, args => {
        f => sub ($line) {
            state $line_no = 0;
            sprintf '%4d : %s', ++$line_no, $line
        }
    }));

    $input->send( Yakt::Streams::Subscribe->new( subscriber => $map ) );
    $map->send( Yakt::Streams::Subscribe->new( subscriber => $output ) );

});

$sys->loop_until_done;

like($MyObserver::RESULTS[-1], qr/# THE END$/, '... got the expected last line for fh');

done_testing;

# THE END
