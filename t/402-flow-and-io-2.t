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

my $sys = Yakt::System->new->init(sub ($context) {

    my $fh_in = IO::File->new;
    $fh_in->open($INPUT, 'r');

    my $fh_out = IO::File->new;
    $fh_out->open($OUTPUT, '+>');

    my $input  = $context->spawn( Yakt::Props->new( class => Yakt::IO::Actors::StreamReader::, args => { fh => $fh_in  }));
    my $output = $context->spawn( Yakt::Props->new( class => Yakt::IO::Actors::StreamWriter::, args => { fh => $fh_out }));

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

subtest '... did this work' => sub {
    my $expected = IO::File->new;
    $expected->open($INPUT, 'r');

    my $got = IO::File->new;
    $got->open($OUTPUT, 'r');

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
