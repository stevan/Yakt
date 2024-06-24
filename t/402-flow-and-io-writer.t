#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::System';

use Yakt::Streams;

use Yakt::IO::Actors::StreamReader;
use Yakt::IO::Actors::StreamWriter;
use Yakt::Streams::Actors::Operator::Map;

my $INPUT  = __FILE__;
my $OUTPUT = __FILE__.'.temp';

unlink $OUTPUT if -e $OUTPUT;

class MySingleObserver :isa(Yakt::Streams::Actors::Observer::ForSingle) {
    use Yakt::Logging;

    method on_success ($context, $message) {
        $context->logger->log(INFO, "->OnSuccess called" ) if INFO;
        $context->stop;
    }

    method on_error ($context, $message) {
        $context->logger->log(INFO, "->OnError called with error: ".$message->error ) if INFO;
        $context->stop;
    }
}

my $sys = Yakt::System->new->init(sub ($context) {

    my $fh_in  = IO::File->new($INPUT,  'r');
    my $fh_out = IO::File->new($OUTPUT, 'w');

    Yakt::Streams::Composers::Flow->new
        ->from(Yakt::Props->new( class => Yakt::IO::Actors::StreamReader::, args => { fh => $fh_in  } ))
        ->map( sub ($line) {
            state $line_no = 0;
            sprintf '%4d : %s', ++$line_no, $line
        })
        ->to(Yakt::Props->new( class => Yakt::IO::Actors::StreamWriter::, args => { fh => $fh_out } ))
        ->spawn( $context )
        ->send(
            Yakt::Streams::Subscribe->new(
                subscriber => $context->spawn( Yakt::Props->new(class => MySingleObserver::))
            )
        );

});

$sys->loop_until_done;

subtest '... did this work' => sub {
    my $expected = IO::File->new($INPUT, 'r');
    my $got      = IO::File->new($OUTPUT, 'r');

    my @got      = <$got>;
    my @expected = <$expected>;

    is(
        (scalar grep /^\s*\d+\s\:\s/, @got),
        (scalar @expected),
        '... got all the rows with numbers in front of them'
    );

    my $error = false;
    foreach my $i ( 0 .. $#expected) {
        unless (($got[$i] =~ s/^\s*\d+\s\:\s//r) eq $expected[$i]) {
            $error = true;
        }
    }
    ok(!$error, '... all the lines match');

    unlink $OUTPUT;
};

done_testing;

# THE END
