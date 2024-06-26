#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::System';

use IO::Socket::SSL;
use HTTP::Request;

class Google :isa(Yakt::Actor) {
    use Yakt::Logging;

    our $MESSAGED   = 0;
    our $STARTED    = 0;
    our $RESTARTED  = 0;
    our $STOPPING   = 0;
    our $STOPPED    = 0;
    our $SUCCESS    = 0;
    our $CONNECTED  = 0;

    field $watcher;
    field $timeout;

    method signal ($context, $signal) {
        if ($signal isa Yakt::System::Signals::Started) {
            $STARTED++;
            $context->logger->log(INFO, sprintf 'Started %s' => $context->self ) if INFO;

            my $google = IO::Socket::SSL->new(
                PeerAddr => 'www.google.com:443',
                Blocking => 0
            ) || do {
                $context->logger->log(ERROR, 'OH NOES: Could not connect SSL to google!!') if ERROR;
                $context->system->shutdown;
                return;
            };

            $context->logger->log(INFO, sprintf 'Connected to %s' => $google ) if INFO;

            $watcher = Yakt::System::IO::Selector::Socket->new( ref => $context->self, fh => $google );
            $watcher->is_connecting = true;

            $context->system->io->add_selector( $watcher );

            $timeout = $context->schedule( after => 2, callback => sub {
                $context->logger->log(INFO, 'Timeout for connecting to Google!' ) if INFO;
                $watcher->reset;
            });

        } elsif ($signal isa Yakt::System::Signals::IO::IsConnected) {
            $CONNECTED++;
            $context->logger->log(INFO, sprintf 'IsConnected %s' => $context->self ) if INFO;
            $timeout->cancel;

            $watcher->is_connecting = false;
            $watcher->is_writing = true;

            $timeout = $context->schedule( after => 2, callback => sub {
                $context->logger->log(INFO, 'Timeout for reading from Google!' ) if INFO;
                $watcher->reset;
            });

        } elsif ($signal isa Yakt::System::Signals::IO::GotConnectionError) {
            $context->logger->log(INFO, sprintf 'GotConnectionError %s' => $context->self ) if INFO;
            $timeout->cancel;
            $watcher->reset;

        } elsif ($signal isa Yakt::System::Signals::IO::GotError) {
            $context->logger->log(INFO, sprintf 'GotError %s' => $context->self ) if INFO;
            $timeout->cancel;
            $watcher->reset;

        } elsif ($signal isa Yakt::System::Signals::IO::CanWrite) {
            $context->logger->log(INFO, sprintf 'CanWrite %s' => $context->self ) if INFO;
            $timeout->cancel;

            $watcher->fh->print( HTTP::Request->new( GET => '/' )->as_string );

            $watcher->is_writing = false;
            $watcher->is_reading = true;

            $timeout = $context->schedule( after => 2, callback => sub {
                $context->logger->log(INFO, 'Timeout for reading from Google!' ) if INFO;
                $watcher->reset;
            });

        } elsif ($signal isa Yakt::System::Signals::IO::CanRead) {
            $context->logger->log(INFO, sprintf 'CanRead %s' => $context->self ) if INFO;

            my $socket = $watcher->fh;

            my $expected = "HTTP/1.0 200 OK\r\n";

            my $len = sysread $socket, my $line, length $expected;

            if (not defined $len) {
                $context->logger->log( INFO, "... Haven't gotten any data" ) if INFO;
                return;
            }

            $context->logger->log(INFO, "Read len($len) from Google!" ) if INFO;

            Test::More::is($line, $expected, '... got the correct response');

            $timeout->cancel;
            $watcher->reset;
            $watcher->fh->close;

            $SUCCESS++;

            $context->stop;

        } elsif ($signal isa Yakt::System::Signals::Stopping) {
            $STOPPING++;
            $context->logger->log( INFO, sprintf 'Stopping %s' => $context->self ) if INFO
        } elsif ($signal isa Yakt::System::Signals::Restarting) {
            $RESTARTED++;
            $context->logger->log( INFO, sprintf 'Restarting %s' => $context->self ) if INFO
        } elsif ($signal isa Yakt::System::Signals::Stopped) {
            $STOPPED++;
            $context->logger->log( INFO, sprintf 'Stopped %s' => $context->self ) if INFO
        }
        else {
            die "Unknown Signal($signal)";
        }
    }

    method apply ($context, $message) {
        $MESSAGED++;
        $context->logger->log(INFO, "HELLO" ) if INFO;
        return true;
    }
}

my $sys = Yakt::System->new->init(sub ($context) {
    my $g1 = $context->spawn( Yakt::Props->new( class => 'Google' ) );
    my $g2 = $context->spawn( Yakt::Props->new( class => 'Google' ) );
    my $g3 = $context->spawn( Yakt::Props->new( class => 'Google' ) );
});

$sys->loop_until_done;

is($Google::MESSAGED,  0, '... got the expected messaged');
is($Google::RESTARTED, 0, '... got the expected restarted');
is($Google::STARTED,   3, '... got the expected started');
is($Google::STOPPING,  3, '... got the expected stopping');
is($Google::STOPPED,   3, '... got the expected stopped');
is($Google::SUCCESS,
    $Google::CONNECTED ? 3 : 0,
    '... got the expected success (if we are connected or not)');

done_testing;

