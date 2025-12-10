#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::System';

class ProcessMessage :isa(Yakt::Message) {
    field $value :param;
    method value { $value }
}

class ResumeActor :isa(Yakt::Actor) {
    our @PROCESSED;
    our $ERROR_COUNT = 0;

    method on_process :Receive(ProcessMessage) ($context, $message) {
        if ($message->value eq 'fail') {
            $ERROR_COUNT++;
            die "Intentional failure on 'fail' message";
        }
        push @PROCESSED => $message->value;
        if ($message->value eq 'stop') {
            $context->stop;
        }
    }
}

subtest 'Resume supervisor skips failed message and continues' => sub {
    @ResumeActor::PROCESSED = ();
    $ResumeActor::ERROR_COUNT = 0;

    my $sys = Yakt::System->new->init(sub ($context) {
        my $actor = $context->spawn(Yakt::Props->new(
            class      => 'ResumeActor',
            supervisor => Yakt::System::Supervisors::Resume->new
        ));

        $actor->send(ProcessMessage->new( value => 'first' ));
        $actor->send(ProcessMessage->new( value => 'fail' ));
        $actor->send(ProcessMessage->new( value => 'second' ));
        $actor->send(ProcessMessage->new( value => 'stop' ));
    });

    $sys->loop_until_done;

    is($ResumeActor::ERROR_COUNT, 1, '... error occurred once');
    is_deeply(
        \@ResumeActor::PROCESSED,
        ['first', 'second', 'stop'],
        '... processed all non-failing messages (skipped failed one)'
    );
};

subtest 'Resume supervisor handles multiple failures' => sub {
    @ResumeActor::PROCESSED = ();
    $ResumeActor::ERROR_COUNT = 0;

    my $sys = Yakt::System->new->init(sub ($context) {
        my $actor = $context->spawn(Yakt::Props->new(
            class      => 'ResumeActor',
            supervisor => Yakt::System::Supervisors::Resume->new
        ));

        $actor->send(ProcessMessage->new( value => 'a' ));
        $actor->send(ProcessMessage->new( value => 'fail' ));
        $actor->send(ProcessMessage->new( value => 'b' ));
        $actor->send(ProcessMessage->new( value => 'fail' ));
        $actor->send(ProcessMessage->new( value => 'c' ));
        $actor->send(ProcessMessage->new( value => 'stop' ));
    });

    $sys->loop_until_done;

    is($ResumeActor::ERROR_COUNT, 2, '... two errors occurred');
    is_deeply(
        \@ResumeActor::PROCESSED,
        ['a', 'b', 'c', 'stop'],
        '... all successful messages processed'
    );
};

done_testing;
