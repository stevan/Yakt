#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::System';

class RetryMessage :isa(Yakt::Message) {}

class RetryActor :isa(Yakt::Actor) {
    our $ATTEMPT_COUNT = 0;
    our $MAX_ATTEMPTS  = 3;
    our $SUCCESS       = 0;

    method on_retry :Receive(RetryMessage) ($context, $message) {
        $ATTEMPT_COUNT++;
        if ($ATTEMPT_COUNT < $MAX_ATTEMPTS) {
            die "Failing on attempt $ATTEMPT_COUNT";
        }
        $SUCCESS = 1;
        $context->stop;
    }
}

subtest 'Retry supervisor re-delivers message on failure' => sub {
    $RetryActor::ATTEMPT_COUNT = 0;
    $RetryActor::MAX_ATTEMPTS  = 3;
    $RetryActor::SUCCESS       = 0;

    my $sys = Yakt::System->new->init(sub ($context) {
        my $actor = $context->spawn(Yakt::Props->new(
            class      => 'RetryActor',
            supervisor => Yakt::System::Supervisors::Retry->new
        ));
        $actor->send(RetryMessage->new);
    });

    $sys->loop_until_done;

    is($RetryActor::ATTEMPT_COUNT, 3, '... message was retried until success');
    is($RetryActor::SUCCESS, 1, '... eventually succeeded');
};

class CountingRetryActor :isa(Yakt::Actor) {
    our $ATTEMPTS = 0;

    field $fail_count :param = 2;

    method on_retry :Receive(RetryMessage) ($context, $message) {
        $ATTEMPTS++;
        if ($ATTEMPTS <= $fail_count) {
            die "Attempt $ATTEMPTS failed";
        }
        $context->stop;
    }
}

subtest 'Retry supervisor retries configurable number of times' => sub {
    $CountingRetryActor::ATTEMPTS = 0;

    my $sys = Yakt::System->new->init(sub ($context) {
        my $actor = $context->spawn(Yakt::Props->new(
            class      => 'CountingRetryActor',
            args       => { fail_count => 5 },
            supervisor => Yakt::System::Supervisors::Retry->new
        ));
        $actor->send(RetryMessage->new);
    });

    $sys->loop_until_done;

    is($CountingRetryActor::ATTEMPTS, 6, '... retried 5 times then succeeded on 6th');
};

done_testing;
