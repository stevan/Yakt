#!perl

use v5.40;
use experimental qw[ class ];

class Yakt::Message {
    use Yakt::Logging;

    use overload '""' => 'to_string';

    field $reply_to :param :reader = undef;
    field $sender   :param :reader = undef;
    field $payload  :param :reader = undef;

    method to_string {
        join '' => blessed $self, '(', join ', ' => (
            ($reply_to ? "reply_to: $reply_to" : ()),
            ($sender   ?   "sender: $sender"   : ()),
            ($payload  ?  "payload: $payload"  : ()),
        ),')';
    }
}

__END__

=pod

=encoding UTF-8

=head1 NAME

Yakt::Message - Base class for actor messages

=head1 SYNOPSIS

    # Define a message type
    class Greeting :isa(Yakt::Message) {
        field $name :param :reader;
    }

    # Send a message
    $actor_ref->send(Greeting->new( name => 'World' ));

    # Message with reply address
    $actor_ref->send(Request->new(
        sender   => $context->self,
        reply_to => $context->self,
        payload  => { query => 'status' }
    ));

=head1 DESCRIPTION

C<Yakt::Message> is the base class for all messages sent between actors.
Messages are simple data objects that carry information from one actor to another.

You can use C<Yakt::Message> directly with the built-in fields, or create
subclasses with custom fields.

=head1 STATUS

B<Stable> - Core API is stable.

=head1 BUILT-IN FIELDS

All optional, for convenience:

=head2 sender

    field $sender :param :reader = undef;

A Ref to the actor that sent this message. Useful for replies.

=head2 reply_to

    field $reply_to :param :reader = undef;

A Ref to send the response to. May differ from C<sender> for forwarding patterns.

=head2 payload

    field $payload :param :reader = undef;

Generic data payload. Useful for simple messages without custom classes.

=head1 DEFINING CUSTOM MESSAGES

For type-safe message handling, define custom message classes:

    class AddItem :isa(Yakt::Message) {
        field $item :param :reader;
        field $quantity :param :reader = 1;
    }

    class RemoveItem :isa(Yakt::Message) {
        field $item_id :param :reader;
    }

Then handle them with typed receivers:

    method add :Receive(AddItem) ($context, $message) {
        push @items => ($message->item) x $message->quantity;
    }

    method remove :Receive(RemoveItem) ($context, $message) {
        @items = grep { $_->id ne $message->item_id } @items;
    }

=head1 REPLY PATTERNS

Common pattern for request/response:

    # Requester
    $server->send(GetStatus->new( reply_to => $context->self ));

    method on_status :Receive(StatusResponse) ($context, $message) {
        # Handle response
    }

    # Server
    method on_get_status :Receive(GetStatus) ($context, $message) {
        $message->reply_to->send(StatusResponse->new( status => $self->status ));
    }

=head1 STRINGIFICATION

Messages stringify to a readable format showing their type and fields:

    Greeting(sender: Ref(Client)[001], payload: hello)

=head1 SEE ALSO

L<Yakt::Actor>, L<Yakt::Ref>

=cut
