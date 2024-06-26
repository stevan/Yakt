<!---------------------------------------------------------------------------->
# TODO
<!---------------------------------------------------------------------------->

- implement the Contract!
    - https://reactivex.io/documentation/contract.html


## Aggregate Observers

- There should be an Observer + Single type
    - aggregates all the OnNext items
        - returns the final aggregated value to OnSuccess
        - or returns OnError
    - the StreamWriter already implements this

- This can also handle Collect.Join() and such things
    - anything that reduces a collect to a single value (Scalar, ArrayRef, etc)

- This will be the Sink for Flows
    - and pass its OnSuccess/OnError results to the Flow to be its "return value"
        - because Flows are Singles


## Become/Unbecome

- make become/unbcome just do one thing
    - add become_stacked/unbecome_stacked for that if desired
    - how do they work together?

- find a place for the `Behaviors {}` helper
    - should I accept a CODE ref as well?
    - do they have any kind of lifecycle?
    - do they accept signals?

## IO

- create a protocol for reading/writing
    - it should be based an Observables

- build actors for this
    - Stream
    - Socket

## Context

- add method for adding Selectors
    - go via System

## Loggers

- Make the Logger async using a watcher
    - or a special purpose watcher perhaps

## Supervisors

- Supervisors need to be configurable for given errors
    - some kind of error dispatch table (`match`)

## Child Supervision

- need to add this

## Errors

- need to distinguish between errors to be caught, and fatal errors which
  should start the shutdown process

## Signals

- add exporters and constructors for Ready and Terminated as those are the only
  two which are used by Users

## Shutdown

- detect the shutdown precursors better
    - we need to also be able to catch zombies
        - and not just loop forever ...

<!---------------------------------------------------------------------------->
# Maybe
<!---------------------------------------------------------------------------->

## Perl Stuff

`use warnings FATAL => qw[ once ]`

This will make using symbols better as this will make this a compile time
check.

Also check out https://metacpan.org/pod/strictures#VERSION-2 for this as well.



