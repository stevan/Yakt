#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::Props';
use ok 'Yakt::System::Supervisors';

subtest 'Props with default supervisor' => sub {
    my $props = Yakt::Props->new( class => 'MyActor' );

    isa_ok($props->supervisor, 'Yakt::System::Supervisors::Stop',
        '... default supervisor is Stop');
};

subtest 'Props with Stop supervisor' => sub {
    my $props = Yakt::Props->new(
        class => 'MyActor',
    )->with_supervisor(Yakt::System::Supervisors::Stop->new);

    isa_ok($props->supervisor, 'Yakt::System::Supervisors::Stop',
        '... supervisor is Stop');
};

subtest 'Props with Restart supervisor' => sub {
    my $props = Yakt::Props->new(
        class => 'MyActor',
    )->with_supervisor(Yakt::System::Supervisors::Restart->new);

    isa_ok($props->supervisor, 'Yakt::System::Supervisors::Restart',
        '... supervisor is Restart');
};

subtest 'Props with Resume supervisor' => sub {
    my $props = Yakt::Props->new(
        class => 'MyActor',
    )->with_supervisor(Yakt::System::Supervisors::Resume->new);

    isa_ok($props->supervisor, 'Yakt::System::Supervisors::Resume',
        '... supervisor is Resume');
};

subtest 'Props with Retry supervisor' => sub {
    my $props = Yakt::Props->new(
        class => 'MyActor',
    )->with_supervisor(Yakt::System::Supervisors::Retry->new);

    isa_ok($props->supervisor, 'Yakt::System::Supervisors::Retry',
        '... supervisor is Retry');
};

subtest 'with_supervisor returns self for chaining' => sub {
    my $props = Yakt::Props->new( class => 'MyActor' );
    my $result = $props->with_supervisor(Yakt::System::Supervisors::Restart->new);

    is(refaddr($result), refaddr($props), '... with_supervisor returns self');
};

done_testing;
