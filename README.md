
# zpn

A command line RPN calculator tool with multiple sessions.

## Putting Numbers in the Stack

You can enter numbers into the stack by typing out the number and pressing enter. Multiple numbers can be entered at a time by separating them with whitespace.

## Performing Operations

You can perform operations by postfixing them on the numbers. 
An example would be `4 5 +` resulting in 9.
Unary operations can be entering the operation after the number you wish to perform 
the operation on.
Binary operations are performed on the previous two numbers entered on the stack.
You can also remove the last number from the stack by using the operation `del`, multiple values can be 
deleted using `del:` followed by a number that doesn't exceed the stack size. If you want to delete all entries in the
stack use `clear`.
The last two numbers on the stack can be swapped using the `swap` command.
The numbers can be cyclically permuted one using the command `cyc` or `cycle`, 
or any integer multiple of cyclic permutations by specifying a signed integer like 
so `cyc:-2` (negative sign reverses permutation). One can pull any number from anywhere in the stack to the bottom by using the `get:x` 
where x is the index (counting starts from 0). To insert a number into a particular spot in the stack we can use `insert:idx:num` where 
`idx` is the `idx` (can be any integer value with negatives allowed) and `num` is a floating point number.


Any actions can be undone by using `undo` and redone by using `redo` if
 multiple undos or redos are required use syntax similar to the cyclic permutation 
 syntax, e.g. `undo:2` for two undos in a row, and `redo:2` for two redos in a row. 
The last element in the stack can be copied by using `copy` or `cpy`.

There is also support for stack wide elementwise operations `map:<un_func>` to apply
a unary function to each number and `el:<num>:<bin_func>` to apply a binary function
to each number with a fixed number as the second argument `<num>`. Reducing across the
stack of the session is possible with `reduce:<bin_func>` e.g. `reduce:+` will sum all
numbers in the stack together.

## Manipulating Sessions
New session can be create with the command `new:<name_of_session>` and can be moved to 
by `go_to:<name_of_session>` or `goto:<name_of_session>`. You can remove a session using
`rm:<name_of_session>`. A list of sessions can be printed at any time by typing `sess`.

## Available Unary Operations

Negation `neg`

Multiplicative Inverse `inv`

Absolute value `abs`

Square `sq` or `square`

Square root `sqrt`

Cube `cub` or `cube`

Cube root `cubrt` or `cubert`

Exponential `exp`

Natural Logarithm `ln`

Logarithm base 10 `log10`

Logarithm base 2 `log2`

Sine `sin`

Arcsine `asin`

Cosine `cos`

Arccosine `acos`

Tangent `tan`

Arctangent `atan`

Hyperbolic sine `sinh`

Hyperbolic arcsine `asinh`

Hyperbolic cosine `cosh`

Hyperbolic arccosine `acosh`

Hyperbolic tangent `tanh`

Hyperbolic arctangent `atanh`


## Available Binary Operations

Addition `+`

Subtraction `-`

Multiplication `*`

Division `/`

Power of `^` or `pow`
