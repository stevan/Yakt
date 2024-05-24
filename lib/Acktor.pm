#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

class Acktor {
    method apply ($context, $message) {}

    # Event handlers for Signals
    method post_start  ($context) { say sprintf 'Started    %s' => $context->self }
    method pre_stop    ($context) { say sprintf 'Stopping   %s' => $context->self }
    method pre_restart ($context) { say sprintf 'Restarting %s' => $context->self }
    method post_stop   ($context) { say sprintf 'Stopped    %s' => $context->self }
}

