# TODO

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

class PingPong::Start :isa(Actor::Message) {}
class PingPong::Ping  :isa(Actor::Message) {}
class PingPong::Pong  :isa(Actor::Message) {}

class PingPong :isa(Actor::Protocol) {
    method Start ($max_ping) { PingPong::Start->new( body => $max_ming ) }

    method Ping { PingPong::Ping->new }
    method Pong { PingPong::Pong->new }
}

class PingPong :isa(Actor::Protocol) {
    method Start :Message(Int);
    method Ping  :Message;
    method Pong  :Message;
}

class Ping :isa(Actor) {
    use Actor::Protocols PingPong => qw[ Start Ping Pong ];

    field $pong;

    field $count = 0;
    field $max   = inf;

    method OnActivation :Signal(Lifcycle::Activate) {
        $pong = spawn '/pong' => Props[ Pong => { ping => $self } ];
    }

    method Start :Recieve(PingPong::Start) ($m) {
        $max = $max_ping;
        $pong->send(Pong);
    }

    method Ping :Receive(PingPong::Ping) {
        if ($count < $max) {
            context->exit;
            return;
        }
        $count++;
        say "Got Ping($count) sending Pong";
        $pong->send(Pong);
    }
}

class Pong :isa(Actor) {
    use Actor::Protocols PingPong => qw[ Ping Pong ];

    field $ping :param;

    field $count = 0;

    method Pong :Receive(PingPong::Pong) {
        $count++;
        say "Got Pong($count) sending Ping";
        $ping->send(Ping);
    }
}
```

