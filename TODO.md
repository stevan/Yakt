# TODO

## Concepts

### User Level

- Actor

This is user written code, and includes access to a Behavior instance.

An Actor has two APIs, the first is the actor's syncronous API which
is defined by it's methods, as with normal OOP; the second is the
Actor's Behavior, which provides the asycnronous API.

The Actor is a managed object, which means that it is not possible to
have direct access to this object, outside if your class definition.
This means that all calls much come via the asyncronous API of the
Behavior, whose code can then call the syncronous methods of the Actor.

- Behavior

This is system code, but is configured via the user code written in the Actor.

* It contains the message callbacks which are the asyncronous API to this class.
* The asyncronous API can only be called by sending a message through the System.

The Behavior is created via the Actor code, but should be considered to be a
static value associated with the Actor's class. Meaning that we should have the
same number of Behavior instances as we have types of Actors

### External System Level

- Ref

This is a reference to an Actor instance and is the means by which we can asyncronously
communicate with that Actor instance.




























- needs a loop_until_done method on System
- System needs to note the currently executing context
    - and make it available to others

## Lifecycle

https://proto.actor/docs/images/actorlifecycle.png

There are two sides to this coin:

1) The signals which are sent, by the system, to the Mailbox, to control the Actor
2) The methods on the actor which are called by the Mailbox in response to it processing signals

### Lifecycle States

- Started
    - the actor has been started but not done any work yet

- Alive
    - the actor is available for messages

- Stopping
    - the actor shutting down and is about to be stopped

- Restarting
    - the actor shutting down and is about to be restarted

- Stopped
    - the actor has been fully shutdown and will be removed

### Failure

When an actor throws an error processing a message, the following happens:

- Mailbox is suspended
    - NOTE: steal this from Acktor

- Mailbox applies the actor supervision strategy
    - Resume
        - just retry the message and keep going
    - Stop
        - immediately send the Stopping signal to Actor to process
        - NOTE: before final deactivation, the Stopped signal will be sent and Mailbox destroyed
    - Restart
        - immediately send the Restarting signal to Actor to process
        - once this has been processed, Mailbox restarts the actor
            - and sends the Started message to the Actor

## Perl Stuff

`use warnings FATAL => qw[ once ]`

This will make using symbols better as this will make this a compile time
check.

Also check out https://metacpan.org/pod/strictures#VERSION-2 for this as well.


## Syntax Sketch


```ruby

class PingPong       :isa(Actor::Protocol) {}
class PingPong::Ping :isa(Actor::Message)  {}
class PingPong::Pong :isa(Actor::Message)  {}

class Ping :isa(Actor::Behavior) {
    field $pong;
    field $count = 0;

    method OnStart :Signal(Lifcycle::Started) {
        $pong = spawn '/pong' => Props[Pong::, ping => context->self ];
    }

    method Ping :Receive(PingPong::Ping) {
        $count++;
        $pong->send( PingPong::Pong->new );
        if ($count > 9) {
            $context->stop;
        }
    }
}

class Pong :isa(Actor::Behavior) {
    field $ping :param;

    method Pong :Receive(PingPong::Pong) {
        $ping->send( PingPong::Ping->new );
    }
}
```

