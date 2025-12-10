#!perl

use v5.40;
use experimental qw[ class ];

use Yakt::System::Supervisors;

class Yakt::Props {
    use Yakt::Logging;

    use overload '""' => \&to_string;

    field $class      :param;
    field $args       :param = {};
    field $alias      :param = undef;
    field $supervisor :param = undef;

    field $logger;

    ADJUST {
        $logger = Yakt::Logging->logger($self->to_string) if LOG_LEVEL;
    }

    method class { $class }
    method alias { $alias }

    method with_supervisor ($s) { $supervisor = $s; $self }
    method supervisor           { $supervisor //= Yakt::System::Supervisors::Stop->new }

    method new_actor {
        $logger->log(DEBUG, "$self creating new actor($class)" ) if DEBUG;
        $class->new( %$args );
    }

    method to_string { "Props[$class]" }
}

__END__

=pod

=encoding UTF-8

=head1 NAME

Yakt::Props - Actor configuration and factory

=head1 SYNOPSIS

    use Yakt::Props;

    # Basic Props
    my $props = Yakt::Props->new( class => 'MyActor' );

    # With constructor args
    my $props = Yakt::Props->new(
        class => 'Counter',
        args  => { initial_count => 10 }
    );

    # With an alias for lookup
    my $props = Yakt::Props->new(
        class => 'Logger',
        alias => '//usr/logger'
    );

    # With a custom supervisor
    my $props = Yakt::Props->new(
        class      => 'Worker',
        supervisor => Yakt::System::Supervisors::Restart->new
    );

    # Fluent supervisor configuration
    my $props = Yakt::Props->new( class => 'Worker' )
        ->with_supervisor(Yakt::System::Supervisors::Retry->new);

    # Spawn from Props
    my $ref = $context->spawn($props);

=head1 DESCRIPTION

C<Yakt::Props> is the configuration object used to create actors. It specifies
the actor class, constructor arguments, optional alias, and supervision strategy.

Props are immutable recipes - you can reuse the same Props to spawn multiple
identical actors.

=head1 STATUS

B<Stable> - Core API is stable.

=head1 CONSTRUCTOR

=head2 new(%options)

    my $props = Yakt::Props->new(
        class      => 'MyActor',       # required
        args       => { ... },          # optional, passed to actor constructor
        alias      => '//usr/name',     # optional, for lookup
        supervisor => $supervisor_obj,  # optional, default is Stop
    );

=head1 METHODS

=head2 class

    my $class_name = $props->class;

Returns the actor class name.

=head2 alias

    my $alias = $props->alias;

Returns the alias, or C<undef> if none set.

=head2 supervisor

    my $supervisor = $props->supervisor;

Returns the supervisor strategy. Defaults to L<Yakt::System::Supervisors::Stop>.

=head2 with_supervisor($supervisor)

    $props->with_supervisor(Yakt::System::Supervisors::Restart->new);

Sets the supervisor and returns C<$self> for chaining.

=head2 new_actor

    my $actor = $props->new_actor;

Creates a new actor instance. Called internally by the Mailbox.

=head1 SUPERVISION STRATEGIES

Four built-in supervisors are available:

=over 4

=item L<Yakt::System::Supervisors::Stop> (default)

Stops the actor when a message handler throws.

=item L<Yakt::System::Supervisors::Resume>

Skips the failed message and continues processing.

=item L<Yakt::System::Supervisors::Retry>

Re-delivers the failed message (careful of infinite loops!).

=item L<Yakt::System::Supervisors::Restart>

Restarts the actor and re-delivers the message.

=back

=head1 ALIASES

Aliases provide named lookup for actors. The alias namespace is flat and
global to the System. Convention uses path-like strings:

    //usr/workers/pool
    //sys/metrics

Aliases are registered when the actor is spawned and unregistered when it stops.

B<Note:> There's currently no public API to look up actors by alias.

=head1 SEE ALSO

L<Yakt::Actor>, L<Yakt::Context>, L<Yakt::System::Supervisors::Supervisor>

=cut
