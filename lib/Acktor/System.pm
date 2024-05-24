#!perl

use v5.38;
use experimental qw[ class builtin try ];
use builtin      qw[ blessed refaddr true false ];

use Acktor::Mailbox;
use Acktor::Props;
use Acktor::System::Actors::Root;

class Acktor::System {

    field $root;

    field %lookup;
    field @mailboxes;

    method spawn_actor ($props, $parent=undef) {
        say "+++ System::spawn($props)";
        my $mailbox = Acktor::Mailbox->new( props => $props, system => $self, parent => $parent );
        $lookup{ $mailbox->ref->pid } = $mailbox;
        if (my $alias = $mailbox->props->alias ) {
            $lookup{ $alias } = $mailbox;
        }
        push @mailboxes => $mailbox;
        return $mailbox->ref;
    }

    method despawn_actor ($ref) {
        say "+++ System::despawn($ref) for ".$ref->context->props->class ."[".$ref->pid."]";
        if (my $mailbox = $lookup{ $ref->pid }) {
            $lookup{ $ref->pid } = $lookup{ '//sys/dead_letters' };
            if (my $alias = $mailbox->props->alias ) {
                delete $lookup{ $alias };
            }
            $mailbox->stop;
        }
        else {
            warn "ACTOR NOT FOUND: $ref";
        }
    }

    method enqueue_message ($to, $message) {
        say ">>> System::enqueue_message to($to) message($message)";
        if (my $mailbox = $lookup{ $to->pid }) {
            $mailbox->enqueue_message( $message );
        }
        else {
            die "DEAD LETTERS: $to $message";
        }
    }

    method init ($init) {
        $root = $self->spawn_actor(
            Acktor::Props->new(
                class => 'Acktor::System::Actors::Root',
                alias => '//',
                args  => { init => $init }
            )
        );
        $self;
    }

    method tick {
        say "-- start:tick -----------------------------------------";

        my @to_run = grep $_->to_be_run, @mailboxes;

        foreach my $mailbox ( @to_run  ) {
            say "~~ BEGIN tick for $mailbox";
            $mailbox->tick;
            say "~~ END tick for $mailbox";
        }

        @mailboxes = grep !$_->is_stopped, @mailboxes;

        say "-- end:tick -------------------------------------------";
        $self->print_actor_tree($root);
    }

    method loop_until_done {
        say "-- start:loop -----------------------------------------";
        while (1) {
            $self->tick;

            if (my $usr = $lookup{ '//usr' } ) {
                if ( $usr->is_alive && !$usr->children ) {
                    say "/// ENTERING SHUTDOWN ///";
                    $root->context->stop;
                }
            }

            last unless @mailboxes;
        }
        say "-- end:loop -------------------------------------------";
    }

    method print_actor_tree ($ref, $indent='') {
        say sprintf '%s<%s>[%03d]' => $indent, $ref->context->props->class, $ref->pid;
        $indent .= '  ';
        foreach my $child ( $ref->context->children ) {
            $self->print_actor_tree( $child, $indent );
        }
    }

}


