#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Test::More;

use Acktor::System;
use Acktor::Logging;

my $logger = Acktor::Logging::Logger->new( target => 'me' );

my $sys = Acktor::System->new->init(sub ($context) {

    $context->schedule( after => 1, callback => sub {
        $logger->log(INFO, "Hello World!") if INFO;
    });

    $context->schedule( after => 4, callback => sub {
        $logger->log(INFO, "Goodbye World!") if INFO;
    });

    $context->schedule( after => 2, callback => sub {
        $logger->log(INFO, "Good day!") if INFO;
    });
});


$sys->loop_until_done;

