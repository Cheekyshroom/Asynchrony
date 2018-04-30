# Asynchrony (for lack of a better name):

## Overview:
(I suppose this goes without saying, but I'm not too tied to any particular
part of this language, so push back on anything you want).

### Syntax:
So far, a lot of the syntax is iffy because I wanted to simplify the parser
I was writing, however if I end up liking the direction things are going in,
I'll probably rewrite that bit / the whole thing in Perl 6 grammars.
(I'm going to write this in a BNF sort of thing, we'll see how that'll go).

```
Atom     := <lower case word, with no whitespace or ops>
Variable := <a word with any upper case in it>
          | <one that begins with a $>
          | _                   (an underscore, the universal pattern)
Op       := + | - | / | * | %   (classic arithmetic)
          | = | ~               (== and !=)
          | < | >               (comparison ops, no *= as of yet)
          | .                   (string concatenation)
Eval     := \[ * \]             (any ruby expression within brackets)
Expr     := Atom
          | Variable
          | Tuple
          | Expr Op Expr
          | Eval
Tuple    := {Expr, Expr ...}    (expressions seperated by commas, in curly braces)

Guard    := when Expr           (the word when followed by an expression)

Pattern  := Tuple, [Tuple ..., !Tuple ...]
                                (A series of tuples seperated by commas,
                                 Tuples preceded by !s are negative matches)

Body     := [Tuple \| Tuple ...] : [Atom \| Atom ...]
          | Eval
                                (A series of optional tuples seperated by pipes, followed by
                                 A colon, followed by a similar series of optional Atoms (combiner names))
                                (or a ruby eval)

Combiner :=                     (An atom followed by Tuple patterns to match
                                 potentially followed by a guard, followed by a body)
  Atom (Pattern) [Guard] ->
    Body

Input    := /*/ -> Body         (A regexp, followed by a body)

Line     := Combiner;
          | Input;

Program  := Line Program
          | EOF
```

### Breakdown:
As it stands, there are three main parts to my implementation so far:

#### Combining:
Really the only interesting part of the language at the moment, work proceeds by:

Choosing a random combiner like this one (assuming a go combiner exists in the combiner bag)
```
# If a player wants to go north, find a room who's south exit is where they currently are
# Then return a new player who's in that room, along with the room itself
# Also print a message
go({go, north}, {player, Place}, {room, Place', {N, E, Place, W}}) ->
    {player, Place'}
  | {room, Place', {N, E, Place, W}}
  | {print, ("You went north to the " . Place')}
  : print;
```

Matching it with some data in the bag at random
```
# we have one combiner in the bag
go;

{go, north};

{player, foyer};

# (The study is to the north of the foyer)
{room, study, {nil, nil, foyer, nil}};
{room, foyer, {study, nil, nil, nil}};
```

Producing a set of bindings with all the variables in the pattern,
and checking that no two bindings differ in value.

If all the bindings check out, the combiner removes it's matched data from
the bag, removes itself from the combiner bag, and places the results of its combination
back into their respective bags, (leaving us with something like this);

```
# we have one combiner in the bag
print;

{player, study};

{room, study, {nil, nil, foyer, nil}};
{room, foyer, {study, nil, nil, nil}};

{print, "You went north to the study"};
```

This process of combination and result creation proceeds ad infinitum, interspersed only by:

#### Input:
This is currently very much only in place for debugging / minor utility, I really don't know if this
is the right way to handle input in a distributed language.

Essentially, when stdin has some data waiting, our interpreter will read it line by line, and per line:
```
# Check to see if it matches any patterns like 
/go *(.+)/ -> {go, $1}:go;

# If it does, grab all the capture groups from that line, and use bind them to the variables $1 .. $INF
# for use in evaluating the pattern's body, (producing something like)
{go, north};
go;

# for the line
go north

```
#### Output:
Output is by far the most shameful part of what I've done, essentially, all output is handled at this moment
by having a certain class of combiner that
1. Produces no data or other combiners
2. Executes an arbitrary ruby expression, with values from our program interspersed throughout that expression
Ex:
```
print({print, Data}) ->
  [puts %Q#Data#];

```
Print is implemented like that, (It's obviously not quote safe, but that's an issue for another day).

I think the way I chose to do it, however flawed, is a little interesting, as you can write combiners that decide
to print stuff, but as soon as you try and write something that wants to, for instance, count to ten and print the numbers
in order, you need to start writing stupid code like:
```
{count, 0};
count({count, N}, !{print, _}) when N < 11 ->
    {count, N + 1}
  | {print, N}
  : print | count;

```
Which now has to wait until all IO is finished before proceeding with the next iteration.
(Is it a negative that we can even write code like this? Like you were saying, do negative patterns give us too much
 expressive power, and let us synchronize too much?)

## Distribution
At the moment, I can't chose between doing something state-machiney: where individual replicas work on their own, and
then collude to fix issues caused by access conflicts etc (potentially a little ridiculous, but would be nice since we can
pretty easily reason about wether or not individual combiners will conflict with others), or something a little more
consistent-hashingey, where data is spread around, but at least the bulk of the work happens on one node.

I'm also not really sure if we need our system to be strongly consistent, although I'd imagine it'd cause a lot of programmer
headache if it wasn't.

## Possible applications:
At the moment, I can't think of anything too specific, other than the classic map-reducey broad non-collidey sort of problems and simulation ones.
Perhaps there's a certain branch of problems that:
1. Require high fault tolerance
2. Can be broken down into a lot of synchronous / branching steps
3. That potentially, and I think this is important: allow things to have dependencies on intermediate results

I think the whole intermediate results thing is pretty integral to how useful this'll be, in my mind, it'd be annoying to write
a system (in a traditional language), that manipulates some data while waiting on some resources, but that has meaningful uses for 
its partial results along the way. However, it'd be easy in this language as:
1. You'd just model the computation as a series of minor manipulations to that data
2. And any time somebody needed access to that partially modified data, they'd be able to swoop in in the middle of a computation
   and grab it for their purposes

Maybe that'll just create another can of worms in terms of usage (and maybe there isn't much desire for utilisation of partial results in practice).

