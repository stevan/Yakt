# Acktor Protocols

Protocols are API definitions for Actors.

## Messages

Protocols are made up of a set of messages and a description of how they will be used. All protocol messages must be a subclass of the abstract `Message` class, but more often it is better to make them a subclass of the `Command`, `Query` or `Error` classes, which themselves are subclasses of the `Message` class.

### Command

A `Command` is a `Message` subclass which does not expect a response. It can optionally include a `sender` ref if desired, but there should be no expectation of a response.

### Query

A `Query` is a `Message` subclass which *does* expects a response. It requires a `reply_to` ref so that it can send a response to the caller.

### Error

An `Error` is simply a `Command` that has an error payload.

## Protocols

Protocols define an Actor's API through a set of messages and informaton about of how they will be used. Protocols can be define the following things:

- Message that the Actor can `accept`
    - with a possible specific `reply` Message to send back
- Messages that can be `publish`-ed by the Actor
- Errors that the Actor can `throws`

### Protocol Directives

The different directives (`accept`, `accept+reply`, `publish`, `throws`) imply how an API will behave when called. Certain directives (`accept+reply` & `throws`) will require a certain `Message` type, in this case the `Query` message and `Error` types respectively. While others can accept either `Query` or `Command`. The following list details the directives and what types they require.

- `accept`
    - can be either `Query` or `Command`
- `accept+reply`
    - request must be a `Query`
    - and the response can be `Query` or `Command`
- `publish`
    - will typically be a `Command`
        - but could be a `Query` sometimes
- `throws`
    - `Error`

### Protocols and Actors

The defined Protocol objects (as shown above) are best thought of as "interfaces" which can be "implemented" by a given Actor.

However, an Actor automatically defines it's own Protocol. This is inferred from the various receivers defined in the Actor's behavior. However, Not all information can be inferred (for instance, it is hard to infer `publish`). So these inferred protocols need to be enhanced by including other defined protocols, creating the applied protocol for the Actor.

- "defined" Protocol
    - a protocol defined by the user to describe an abstract protocol to be implemented by an Actor
- "inferred" Protocol
    - the protocol inferred from the Actor's own definition
- "applied" Protocol
    - the combination of the generated "protocol" and a set of "defined" protocols in one Protocol

```

class Ping :isa(Command) {}
class Pong :isa(Command) {}

Acktor::Protocol->new(PingPong)
    ->accepts(Ping)
        ->reply(Pong)
    ->accepts(Pong)
        ->reply(Ping);

class PingPongGame::Reset    :isa(Command) {}
class PingPongGame::EndGame  :isa(Query)   {}
class PingPongGame::GameOver :isa(Command) {}

class PingPongGame :isa(Acktor::Actor) {
    use Acktor::Logging;
    use Acktor::Protocol -implements => 'PingPong';

    field $pings = 0;
    field $pongs = 0;

    method reset :Receive(::Reset) ($context, $message) {
        $context->restart
    }

    method end_game :Receive(::EndGame) ($context, $message) {
        $message->reply_to->send(GameOver->new( pings => $pings, pongs => $pongs ));
    }

    method ping :Receive(PingPong::Ping) ($context, $message) {
        $pings++;
        $message->reply_to->send(Pong->new);
    }

    method pong :Receive(PingPong::Pong) ($context, $message) {
        $pongs++;
        $message->reply_to->send(Ping->new);
    }

}

```


### Protocol Definitions

This is best done with an example.

Observables are the combination of two concepts, an Observer and an Observable stream. This means we have two actors which need to interact with one another and so therefore share the same messages.

First we will define the set of messages, using the different message types detailed above.

```

class Subscribe   :isa(Query)   {}
class OnSubscribe :isa(Command) {}
class OnNext      :isa(Command) {}
class OnCompleted :isa(Command) {}
class OnError     :isa(Error)   {}

```

Next we model the simpler `Observer` protocol like so:

```

Acktor::Protocol
    ->new(Observer)
        ->accept(OnSubscribe)
        ->accept(OnNext)
        ->accept(OnCompleted)
        ->accept(OnError);
```

The `Observer` protocol accepts three message types; `OnNext`, `OnCompleted` and `OnError`. It is not expected to reply to any of these messages. This is the simplest protocol, just defining the messages an actor will accept.


Now we model the `Observable` protocol, which the `Observer` interacts with.

```

Acktor::Protocol
    ->new(Observable)
        ->accept(Subscribe)
            ->reply(OnSubscribe)
        ->publish(OnNext)
        ->publish(OnCompleted)
        ->publish(OnError);

```

The `Observable` protocol is a bit trickier. It accepts a `Subscribe` message, and is expected to reply to that message by sending an `OnSubscribe` message to the caller. This means that the `Subscribe` message will be of a `Query`
type, and the protocol will verify that upon creation. Upon getting a subscription request an `Observable` actor will start to publish messages to the subscriber. Since there is no request/response pattern here, we must define this action as a set of messages that are `publish`-ed by the Actor.

It is worth noting that the `publish` directive should not be an exhaustive list of the messages that an actor can send. Instead it should be a list of messages an actor may "push" to another actor (or actors), based on some previously agreed upon contract between the actors. The difference between `publish` and `reply` is that with `reply` it is a guarantee that the the message will be sent, but with `publish` there no guarantee that these messages will be sent.

### Protocol Guarentees

The first thing is that it is possible to verify that an Actor's inferred protocol implements a defined protocol.

The second thing is that it is possible to determine if two protocols are compatible.

For instance, using the examples above, it can be seen that the list of messages that the `Observer` can `accept` are compatible with the list of messages that an `Observerable` will either `publish` or `reply`. This makes it possible for an Actor to verify the capabilities of another Actor before starting any interaction with it. This should be especially handy when doing remote Actor interactions from independent Actor systems.


```

class Open


Acktor::Protocol->new(IO::Streams)
    ->accepts(ReadBytes)
        ->reply(BytesRead)
    ->accepts(WriteBytes)
        ->reply(BytesWritten)






```










