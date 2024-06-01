#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Test::More;

use ok 'Acktor::System';

use IO::Socket::SSL;
use HTTP::Request;

class Google :isa(Acktor) {
    use Acktor::Logging;

    our $MESSAGED   = 0;
    our $STARTED    = 0;
    our $RESTARTED  = 0;
    our $STOPPING   = 0;
    our $STOPPED    = 0;
    our $SUCCESS    = 0;

    field $watcher;
    field $timeout;

    method signal ($context, $signal) {
        if ($signal isa Acktor::Signals::Started) {
            $STARTED++;
            $self->logger->log(INFO, sprintf 'Started %s' => $context->self ) if INFO;

            my $google = IO::Socket::SSL->new('www.google.com:443') || die 'Could not connect SSL to google';
            $self->logger->log(INFO, sprintf 'Connected to %s' => $google ) if INFO;
            $google->print( HTTP::Request->new( GET => '/' )->as_string );

            $watcher = $context->watch( fh => $google, reading => true );
            $timeout = $context->schedule( after => 2, callback => sub {
                $self->logger->log(INFO, 'Timeout for Google!' ) if INFO;
                $watcher->is_reading = false;
            });

        } elsif ($signal isa Acktor::IO::Signals::CanRead) {
            $self->logger->log(INFO, sprintf 'CanRead %s' => $context->self ) if INFO;

            my $socket = $watcher->fh;

            my $expected = "HTTP/1.0 200 OK\r\n";

            my $len = sysread $socket, my $line, length $expected;

            if (not defined $len) {
                $self->logger->log( INFO, "... Haven't gotten any data" ) if INFO;
                return;
            }

            Test::More::is($line, $expected, '... got the correct response');

            $watcher->is_reading = false;
            $timeout->cancel;
            $watcher->fh->close;

            $SUCCESS++;

            $context->stop;

        } elsif ($signal isa Acktor::Signals::Stopping) {
            $STOPPING++;
            $self->logger->log( INFO, sprintf 'Stopping %s' => $context->self ) if INFO
        } elsif ($signal isa Acktor::Signals::Restarting) {
            $RESTARTED++;
            $self->logger->log( INFO, sprintf 'Restarting %s' => $context->self ) if INFO
        } elsif ($signal isa Acktor::Signals::Stopped) {
            $STOPPED++;
            $self->logger->log( INFO, sprintf 'Stopped %s' => $context->self ) if INFO
        }
        else {
            die "Unknown Signal($signal)";
        }
    }

    method apply ($context, $message) {
        $MESSAGED++;
        $self->logger->log(INFO, "HELLO" ) if INFO;
    }
}

my $sys = Acktor::System->new->init(sub ($context) {
    my $g1 = $context->spawn( Acktor::Props->new( class => 'Google' ) );
    my $g2 = $context->spawn( Acktor::Props->new( class => 'Google' ) );
    my $g3 = $context->spawn( Acktor::Props->new( class => 'Google' ) );
});

$sys->loop_until_done;

is($Google::MESSAGED,  0, '... got the expected messaged');
is($Google::RESTARTED, 0, '... got the expected restarted');
is($Google::STARTED,   1, '... got the expected started');
is($Google::STOPPING,  1, '... got the expected stopping');
is($Google::STOPPED,   1, '... got the expected stopped');
is($Google::SUCCESS,   1, '... got the expected success');

done_testing;

