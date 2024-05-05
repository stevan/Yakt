#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

class Actor::Context {
    field $system :param;
    field $parent :param;

    field $ref;
    field @children;

    method has_self         { !! $ref      }
    method self             {    $ref      }
    method assign_self ($r) {    $ref = $r }

    method has_parent   { !! $parent          }
    method has_children { !! scalar @children }

    method parent   { $parent   }
    method children { @children }

    # ...

    method spawn ($path, $props) {
        my $child = $system->spawn_actor( $ref->address->with_path($path), $props, $ref );
        push @children => $child;
        return $child;
    }

    method send_to ($to, $message) {
        $system->deliver_message( $to, $message );
        return;
    }

    method exit {
        if ( @children ) {
            $system->despawn_actor( $_ ) foreach @children;
            $system->despawn_actor( $ref );
        }
        else {
            $system->despawn_actor( $ref );
        }
    }
}
