# TODO


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


- Activation
    - requested from app
    - loaded from storage
    - assigned identity

- Running
    - can be called by the application
    - can persist itself as needed

- Deactivation
    - removed from running state
    - can persist itself if needed



## Perl Stuff

`use warnings FATAL => qw[ once ]`

This will make using symbols better as this will make this a compile time
check.

Also check out https://metacpan.org/pod/strictures#VERSION-2 for this as well.



