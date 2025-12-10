#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::System';

class Ping :isa(Yakt::Message) {}

class RefTestActor :isa(Yakt::Actor) {
    our $REF;
    our $PID;

    method on_started :Signal(Yakt::System::Signals::Started) ($context, $signal) {
        $REF = $context->self;
        $PID = $context->self->pid;
        $context->stop;
    }
}

subtest 'Ref has pid' => sub {
    $RefTestActor::REF = undef;
    $RefTestActor::PID = undef;

    my $sys = Yakt::System->new->init(sub ($context) {
        $context->spawn(Yakt::Props->new( class => 'RefTestActor' ));
    });

    $sys->loop_until_done;

    ok(defined $RefTestActor::REF, '... ref is defined');
    ok(defined $RefTestActor::PID, '... pid is defined');
    ok($RefTestActor::PID > 0, '... pid is positive');
};

subtest 'Ref stringifies' => sub {
    $RefTestActor::REF = undef;

    my $sys = Yakt::System->new->init(sub ($context) {
        $context->spawn(Yakt::Props->new( class => 'RefTestActor' ));
    });

    $sys->loop_until_done;

    like("$RefTestActor::REF", qr/Ref\(RefTestActor\)/, '... ref stringifies correctly');
};

done_testing;
