#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Test::More;

## ----------------------------------------------------------------------------

class Actor::Address {
    field $host :param = '-';
    field $path :param = +[];

    my sub normalize_path ($p) { ref $p ? $p : [ grep $_, split '/' => $p ] }

    ADJUST { $path = normalize_path($path) }

    method path { join '/' => @$path }
    method url  { join '/' => $host, $self->path }

    method with_path ($p) {
        Actor::Address->new(
            host => $host,
            path => [ @$path, normalize_path($p)->@* ]
        )
    }
}

class Actor::Props {
    field $class :param;
    field $args  :param = +{};

    method new_actor {
        $class->new( %$args )
    }
}

class Actor::Context {
    field $system :param;
    field $ref    :param;

    method send ($to, $message) {
        $system->send_message( $to, $ref, $message );
    }
}

class Actor::Ref {
    field $address :param;
    field $props   :param;

    field $context;

    method address { $address }
    method props   { $props   }
    method context { $context }

    method set_context ($ctx) { $context = $ctx }

    method send ($message) {
        $context->send( $self, $message );
        return;
    }
}

class Actor::Mailbox {
    field $ref :param;

    field @messages;

    method ref { $ref }
}

class Actor::Runtime {
    field $address :param;

    field %mailboxes;
    field @dead_letters;

    method spawn_actor ($ref) {
        $mailboxes{ $ref->address->url } = Actor::Mailbox->new( ref => $ref );
        return $ref;
    }
}

class Actor::System {
    field $address :param;

    field %cluster;
    field %proto_actors;
    field %active;

    # ...

    method register_actor ( $path, $props ) {
        my $ref = Actor::Ref->new(
            address => $address->with_path( $path ),
            props   => $props,
        );

        $ref->set_context( Actor::Context->new( system => $self, ref => $ref ) );

        $proto_actors{ $path } = $ref;
    }

    method get_actor_at_path ($path) { $proto_actors{ $path } }

    # ...

    method send_message ($to, $from, $message) {

    }

}

## ----------------------------------------------------------------------------

class Foo {}

class Bar {}

## ----------------------------------------------------------------------------

my $system = Actor::System->new( address => Actor::Address->new( host => 'localhost:3000' ) );

my $foo = $system->register_actor( '/foo' => Actor::Props->new( class => Foo:: ) );
isa_ok($foo, 'Actor::Ref' );

my $bar = $system->register_actor( '/bar' => Actor::Props->new( class => Bar:: ) );
isa_ok($bar, 'Actor::Ref' );

is($foo->address->url, 'localhost:3000/foo', '... got the right URL for the ref');
is($bar->address->url, 'localhost:3000/bar', '... got the right URL for the ref');

is($foo, $system->get_actor_at_path( '/foo' ), '... got the actor at that path' );

$foo->send("Hello!");

## ----------------------------------------------------------------------------

done_testing;


__END__





