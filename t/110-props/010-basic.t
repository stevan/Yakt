#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;

use ok 'Yakt::Props';

# Test basic Props creation
subtest 'Props with minimal arguments' => sub {
    my $props = Yakt::Props->new( class => 'MyActor' );

    is($props->class, 'MyActor', '... class is set correctly');
    is($props->alias, undef, '... alias defaults to undef');
    isa_ok($props->supervisor, 'Yakt::System::Supervisors::Stop', '... default supervisor is Stop');
};

subtest 'Props with args' => sub {
    my $props = Yakt::Props->new(
        class => 'MyActor',
        args  => { foo => 'bar', count => 42 }
    );

    is($props->class, 'MyActor', '... class is set correctly');
};

subtest 'Props stringification' => sub {
    my $props = Yakt::Props->new( class => 'MyActor' );

    like("$props", qr/Props\[MyActor\]/, '... stringifies correctly');
};

done_testing;
