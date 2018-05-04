# Asynchrony (for lack of a better name):

## Tl;dr:
Current pseudocode is centered around synchronous processes and data instead of messages, but what if there were a language that more easily captured the essence of distributed algorithms: All messages that one sends, are a function of the messages that have previously been delivered in a given system. By describing systems in terms of the transitions from current knowledge (extant messages) to future shared knowledge (messages still to be sent), I hope to provide, a friendlier model with which to reason about distributed systems.

## Purpose:
Although we've addressed the fact that the real existing issue in designing distributed systems isn't implementing the protocols that are used, but implementing and verifying the glue that combines them, I'm of the opinion that perhaps an alternate programming model could simplify writing protocols for certain domains. 

More specifically, domains in which, not only is there a high chance of partition, but where there's a high chance of multiple large (or partial) partitions, additionally, domains where memory and compute ability on each node is sparse. (Not datacenters).

## Summary:
I'd like to propose a programming model based around the most central ideas of distributed computation, uncontrollable order and messages. In this model, all computation will be expressed in the form functions that combine multiple messages that match certain patterns, and produce more messages.

Distinction has to be made between messages internal to one process, and those that exist globally between processes, for the purpose of performance, and the ability to mandate knowledge sharing in case of partitions.

By expressing all computation within our system as functions that grab a partial state of the system, and replace it with another, we can, in certain cases, easily ensure that certain computations are monotonic, and with the extra property that they're commutative, write programs that can do maximal work in the face of partitions, and depending on the domain, easily provide meaningful temporary results along the way.

In distributed systems, message order is never guaranteed, this model mimics that fact, by purposefully providing no guarantee in which order computations are run.

### An example
Consider the problem of averaging sensor readings from a highly partitionable cluster of IOT sensors. In our model, we can represent readings as tuples of, (S, N, T), where S is a running sum of all values seen, N is the amount of values seen so far, and T is the logical timestep for which we're aggregating sensor readings. We can represent the computation as a function of (S, N, T), (S', N', T) -> (S + S', N + N', T), (with the stipulation that nodes can keep track of the reading with maximal valued N + N' in their cluster, (to maintain a running best guess of the reading, in case of a partition)).

On every logical timestep, each process will produce a value of (Reading, 1, T), which will then be combined with readings from other nodes within a partition, with every computation on each node, the amount of readings will monotonically decrease, until, eventually, one single (S, N, T) tuple will contain the aggregate reading from our sensors. Of course, this isn't terribly impressive, aside from the fact that along the way, one would be able to query any process in the network, and figure out its best guess at the solution for that timestep, no matter how the network is partitioned.

Of course, aggregating values over a network of IOT sensors isn't the hardest problem even in conventional programming models, but it's quite a bit more elegant when one only thinks in terms of what combinations of visible messages produce other messages, and not in terms of what state one must manipulate, or which specific nodes one must communicate with.

## Related work:
Attempts have been made to create languages that better model distributed systems before, but I'm not convinced that anyone has quite explored the path of systems like this, that attempt to make disorderly programming the default, and force synchronicity to be explicit.
- Chemical computing: Similar in spirit (programming in terms of things that combine to create other things), but not centered around distributed systems.
- Lasp: As far as I understand, Lasp merely provides methods with which to control the distribution of data within Erlang programs, but still allows sequential programming.
- JoCaml: Similar to lasp, still focuses on sequential programming, with asynchrony as a side attraction.

## Challenges:
- (The continual question) How do we abstract away details about distributed systems without affecting the performance of the system too much?
- General efficiency and programmability, is this model just a distributed active database, with way too much business logic in the wrong places?
- Would programming in a model centered solely around messages really make combining protocols / writing new ones that much easier?
- How are we going to handle the difference between internal and global messages?
- How will we handle distribution / replication for fault tolerance?

