
# Presenting Yakt - Distributed Actor System for Perl

## Definition: Yak Shaving

- describes a series of small tasks necessary in order to accomplish a larger goal
    - This is what Actors are all about
        - breaking things into small tasks to be run asyncronously
- describes a less useful activity done consciously or subconsciously to procrastinate about a larger but more useful task
    - This describes the project itself, it was my distraction project

## Actors

- Actors are asyncronous Objects
- Distributed Actors are parallel asyncronous Objects

### Asyncronicity vs. Concurrency

- Concurrency is multiple "threads of execution" proceeding forward together
    - Concurrency can be cooperative or preemptive
    - Execution may or may not happen within a single execution context (OS level thread or process)
- Asyncronicity is multiple "threads of execution" proceeding forward together
    - Asyncronicty is always cooprerative
    - Asyncronicty always happens in single execution context

- Asyncronicty is a subset of Concurrency
    - in which threads must cooperate
    - and they share a single execution context

### Cooperative vs. Premeptive Concurrency

- Cooperative threads must periodically yield to allow other threads to run
- Preemptive threads will periodically suspend and yield a thread to allow others to run

- Cooperative threads requires programmer to think about resource usage
    - yield when it is sensible for the overall application to do so
- Preemptive threads remove this concern from the programmer
    - but tend to require syncronization and therefor more defensive code (locks, etc)

### Concurrency vs. Parallelism

- Concurrency is about sharing resources
    - Concurrency is when different threads of execution cooperate together to use the same resources

- Parallelism is about isolating resources
    - Parallelism is when different threads of execution run in isolated processes and have seperate resources

### Distribution vs. Parallelism

- Distribution spreads the work to different machines
- Parallelism spreads the work to different processes

- You can acheive (theoretically) infinite parallelism through distribution

#### Conclsion

- What can Actors Do
    - Actors are spawned into a managed existence
    - Actors communicate via Message Passing
    - Actors can Supervise other Actors
    - Actors have Location Transparency

- Actors provide cooperative concurrency via message passing
- Actors provide distributed parallelism via location transparency

### Spawning Actors

- Actors must be spawned
    - The Actor system creates a new Mailbox for the Actor
    - The return value of `spawn` is a Ref to the Actor stored inside the Mailbox

- Actors can spawn child actors
    - these child actors are tied to the parent
        - via the `parent` and `children` methods of Context

- Actor instance lifecycles are managed by the system
    - There is no direct contact with the Actor instance
        - You interact with a Ref, or reference to the Actor
        - You can send messages to the Actor via the `send` method of the Ref
    - Actor failure is managed
        - by default the Actor will stop
        - but this is contollable via Supervision
    - Lifecycles of Parents and Children Actors are tied together
        - When a parent stops, the children are also stopped
        - When a child stops, the parent is notified
        - this is contollable via Supervision as well

### Message Passing


- There is no direct contact with the Actor instance
    - You can send messages to the Actor via the `send` method of the Ref

- Method Calls are Message Sends
    - Original Smalltalk OO system treated method calls as "message sends"
    - It was C++ & Java that gave us the current virtual dispatch system most OO systems use today

- Method Calls == syncronous && Message Sends == asyncronous
    - Method Calls go through an internal syncronous dispatcher and are called immediately
    - Message Sends go through an internal asyncronous dispatcher and are called within a loop

- Actors communicate by sending messages via the actor's Ref
    - these become method calls to the Actor instance
    - there is no need for syncronization of locks because
        - the system only one message is processed at a time
        - this is the only means of accessing Actor state


### Supervision

- Actor lifecycles are managed by the system
    - this means Supervision of the Actor instance itself
    - and Supervision of any child Actors created

- When a message send and the subseuent method call result in an exception
    - Supervision is triggered
    - Supervision can be controlled via the Supervision Strategy
        - this determines how the Actor will react, such as:
            - Restart
                - stop processing messages and restart the Actor instance
            - Resume
                - drop the current execption causing message and proceed to the next message
            - Retry
                - retry the current message again
            - Stop
                - stop processing messages and stop the Actor instance

- When the parent Actor stops, all its children are also stopped
    - The parent Actor will wait for all it's children to stop before stopping itself
    - controlled structured destruction of Actors
    - this can be controlled via the child Supervision Strategy
        - TBD


### Location Transparency

- Actors communicate via Message Passing
    - this is done indirectly via the Actor's Ref
    - this indirect-ness is what gives us Location Transparency

- Location Transparency means
    - sending a message to a remote Actor is the same as sending to a local Actor
    - the Actor system handles the routing of messages to other Actor systems

## Acktor

### Ping/Pong Example

### Refs & Context

- Refs are how you communicate with Actors

- Context is unique to the Ref and provides access to the underlying Actor System

### Timers

- Timers can be created, run and cancelled

### IO

- IO is also Actor based
    - you can spawn Actor instances to manage I/O streams (stdin/stdout, tty, etc)
    - you can spawn Actor instances to manage TCP connections

- IO is managed via Message Sends
    - send(ReadBytes(size: 1024, timeout: 1s))
        - respond(BytesRead("Some data ..."))
        - respond(ReadError(ESOMETHINGDIDNTWORK))

- IO is done internally with Selectors and Signals
    - so it is possible to write your own

### Supervision

- Strategies are provided

### Distributed Actors

- TBD

## Extra Slides

### Internals

#### Signals

#### Mailboxes

## Other Actor Systems

### Erlang

### Akka (Typed & Classic), Akka.NET

### Proto.Actor & Orleans

