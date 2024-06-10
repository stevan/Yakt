#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Acktor::System';

use Acktor::System::IO::Reader::LineBuffered;

my $b = Acktor::System::IO::Reader::LineBuffered->new( buffer_size => 32 );

my $fh = IO::File->new;

$fh->open(__FILE__, 'r');

my @BUFFER;

my $line_no = 0;
do {
    push @BUFFER => $b->flush_buffer
        if $b->read($fh);

    if (my $e = $b->got_error) {
        warn "GOT ERROR: ".$e;
        last;
    }
} until $b->got_eof;

ok($b->got_eof, '... got the EOF we expected');
is($BUFFER[-1], '# THE END', '... got the expected last line');

#my $i = 0;
#warn join "\n" => map { sprintf '%4d : %s' => ++$i, $_ } @BUFFER;

$fh->close;

done_testing;

# THE END
