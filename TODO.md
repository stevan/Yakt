# TODO


```ruby

class PingPong :isa(Actor::Protocol) {
    method Count :Message( Int );

    method Start :Command( Int );
    method Ping  :Command;
    method Pong  :Command;

    method GetCount :Query :Result( Count );
}

class Ping :isa(Actor) :implements(PingPong) {

    field $pong;

    field $count = 0;
    field $max   = inf;

    method OnActivation :Signal(Lifcycle::Activate) {
        $pong = spawn '/pong' => Props[ Pong => { ping => $self } ];
    }

    method OnDeactivation :Signal(Lifecycle::Deactivate) {
        $pong <- signal *Lifecycle::Deactivate;
    }

    method Start :Recieve(PingPong::Start) ($max_count) {
        $max = $max_count;
        $pong <- event *PingPong::Pong;
    }

    method Ping :Receive(PingPong::Ping) {
        if ($count < $max) {
            context->stop;
            return;
        }
        $count++;
        say "Got Ping($count) sending Pong";
        $pong <- event *PingPong::Pong;
    }

    method Count :Receive(PingPong::GetCount) :Respond(PingPong::Count) {
        sender <- event *PingPong::Count => $count;
    }
}

class Pong :isa(Actor) {
    field $ping :param;

    field $count = 0;

    method Pong :Receive(PingPong::Pong) {
        $count++;
        say "Got Pong($count) sending Ping";
        $ping <- event *PingPong::Ping;
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



