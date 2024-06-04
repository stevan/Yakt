<!---------------------------------------------------------------------------->
# TODO
<!---------------------------------------------------------------------------->

## Shutdown

- don't just stop() the Root, but instead send it a Shutdown signal
    - this can then institute a controlled shutdown

- detect the shutdown precursors better
    - we need to also be able to catch zombies

## IO

- build actors for this
    - Stream
    - Socket

## Context

- add method for adding Selectors
    - go via System

## Supervisors

- Supervisors need to be configurable for given errors
    - some kind of error dispatch table (`match`)

## Child Supervision

- need to add this

## Errors

- need to distinguish between errors to be caught, and fatal errors which
  should start the shutdown process

<!---------------------------------------------------------------------------->
# Maybe
<!---------------------------------------------------------------------------->

## Address

- Re-add these ???

- don't do `0002@localhost:3000/foo/bar`
    - do `localhost:3000/foo/bar/2`
    - it is more REST appropriate and conveys the relationships better
        - i.e. - instance PID(2) of the `/foo/bar` actor

## Messages

- make all messages be able to stringify and desctructure-able
    - but do I really want to enforce a base class?

## Perl Stuff

`use warnings FATAL => qw[ once ]`

This will make using symbols better as this will make this a compile time
check.

Also check out https://metacpan.org/pod/strictures#VERSION-2 for this as well.


<!---------------------------------------------------------------------------->
# Syntax Sketch
<!---------------------------------------------------------------------------->


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

