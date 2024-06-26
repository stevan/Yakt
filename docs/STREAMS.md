# Yakt Streams

### Concepts

DISCLAIMER: The concepts in Yakt Streams differ in many ways from the Rx library
and the Reactive Extensions project. Be careful what you assume.

The main concepts behind Streams is the Observer/Observable contract, which
dictates that Observers consume the messages that Observable publishes and
vica versa. Then adding in Operators, which function both an Observer and
Observable, we can construct asyncronous pipelines. Then it is possible to
use Observer or Reducer, which function as Observer and Single, to reduce
the pipeline into a single syncronous value.

The relationship between an Observer and an Observable is a 1-to-1 relationship
and their lifecycles are typically tied together through the subscription
process. This 1-to-1 relationship means that an Observable does nothing until
it is subcribed to by an Observer, then during the subscription lifetime it
can accept no other subscriptions and only publishes to that Observer. The
Observer can choose to unsubscribe by sendin the Unsubcribe message to the
Observable, which responds with an OnUnsubcribe message. The typical way to
handle the OnUnsubscribe message is to stop the actor, so it is not possible
to get another subscription (unless you override this behavior).

This 1-to-1 relationship with an intertwined Subscription lifetime means that
they are meant to be disposable and used only once for each subscription
lifetime. It also means it is possible to chain subsribe/unsubscribe messages
to create a form of controlled construction/destruction for pipelines.

This intertwined relationship is one of the key differences between Yakt and
Rx, which has a seperate Subscription actor, and Reactive Extensions, which
also has the concept of a Subscription actor, but with back pressure. Note t
hat nothing prevents you from implementing these things in Yakt, as it is
possible to change all the underlying behaviors needed to accomplish it.

Each component (Observer, Observable, Operator, etc) can be thought of as an
expression, and the pipeline (Flow) as a statement containing many expressions
and ending with some kind of terminator (Reducer).

Observer       :: List   -> void
SingleObserver :: Scalar -> void

Single         :: () -> Scalar
Observable     :: () -> List

Operator       :: List -> List
Reducer        :: List -> Scalar

Flow           :: (List ...) -> Scalar


### Observer

An Observer is a consumer for an Observable publisher.

Observers watch Observables by subscribing to them, after which the Observable
will start sending messages to the Observer.

Observers accepts three main messages

- OnNext
- OnCompleted
- OnError

Observers can also accept two event messages, if the Observer should participate
in an Observable pipeline, but they are otherwise optional.

- OnSubscribe
- OnUnsubscribe

Observers do not publish any messages, but can send the following messages to
the Observable, which respond with the appropriate event message above.

- Subscribe
- Unsubscribe

### Observable

Observables accepts a subscription from an Observer and immediately starts
publishing messages to the Observer.

Observables are publishers for Observer consumers.

Observables publish three main messages, each of which the Observer accepts.

- OnNext
- OnCompleted
- OnError

Observables accept the following messages, to control the subscription
process.

- Subscribe
- Unsubscribe

Optionally the Observable can respond to the Observer with the appropriate
event message, if the Observer is expecting it.

- OnSubscribe
- OnUnsubscribe

### Single

Singles are publishers of a single value to an arbitrary subscriber.

A Single is a special kind of Observable which only ever has one value.

For the subscription perspective, it operates the same as an Observable.
But instead of returning a stream of values, it only returns one.

A Single will publish two messages, which the subscriber should accept.

- OnSuccess
- OnError

It should also send and accept all the subscription related messages
the same as an Observable does.

### Operator

Operators are both consumers and publishers of Observables

Operators are both an Observer and an Observable at the same time. This
allows them to accept values, process them, and send them along to the
next Observer (or Operator) in the chain.

Operators are expected to implements the Message interfaces for both
Observers and Observables and behave accordingly in both contexts.

### Reducer

An Reducer is both an Observer and a Single at the same time. This
can be used as the Sink in a Flow to reduce a stream into a single
syncronous value, and then publish that value to a subscriber.

Reducers are expected to implements the Message interfaces for both
Observers and Single and behave accordingly in both contexts.

## Observable Pipelines

An Observable pipeline consists of the following components.

- A source, which implements the Observable messages
- A list of Operators to be chained together
- A sink, which implements either
    - the Observer messages
    - or the Reducer messages (Observer + Single)

### Flow

A Flow is an orchestrator which sets up and runs Observable pipelines.

Flows are actors which spawn Observable/Observer pipelines and
supervise them as child actors.

Flows are Singles and should produce an OnSuccess message, or an
OnError if the pipeline had a fatal issue. The OnSuccess message
can be an empty OnSuccess message (with success being implied),
or a value produced from a Reducer. If there is a Reducer, then
it will publish it's OnSuccess message sometime after the
OnComplete message is received. If there is no Reducer, then it
will publish an empty OnSuccess message if all the child actors
exit successfully. In both cases, if an actor in a pipeline
exits abnormally, the entire pipeline is shutdown.























