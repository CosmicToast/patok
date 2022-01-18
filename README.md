# Patok
The Lua Pattern Tokenizer.

Patok is an efficient tokenizer that lexes based on patterns you provide.
It does this while avoiding slow copy operations, making it reasonably efficient.
What's more is it's written in pure lua!

## Usage

### Constructing the lexer
Requiring patok gives back a constructor function.
You call it (often repeatedly) with lists,
where the key is the name of the pattern (which will come in handy later)
and the value is the pattern itself.
Once you're done defining lexemes, you call it again with no arguments.

Consider the following basic example:
```lua
patok = require 'patok'
lexer = patok {
	number = '%d+',
	word   = '%w+',
}()
```

Note that patterns will be tried *in order*.
However, due to how lua's lists work, lists are unordered.
This is why calling the constructor multiple times can be useful.

Consider the following example:
```lua
lexer = patok {
	foo = 'foo',
	word = '%w+',
}()
```

This lexer may interpret "foo" as either a foo token or a word token - it is ambiguous.
We can make it unambiguous by enforcing an order, as such:
```lua
lexer = patok {
	foo = 'foo',
}{
	word = '%w+',
}()
```

Now "foo" will always be a "foo" lexeme, and never a word.

### Using the lexer
Once your lexer is constructed, you have two methods of interest: reset and next.
Reset will set your lexer up to lex a particular string.
Next will get the next token of the currently set string.

Let's make a simple example, with comments demonstrating the outputs:
```lua
lexer = patok {
	plus  = '%+',
	minus = '%-',
	star  = '%*',
	slash = '/',
	digit = '%d+',
	ws    = '%s+',
}()
lexer:reset '10 + 15'
lexer:next() -- {start=1, stop=2, type="digit", value="10"}
lexer:next() -- {start=3, stop=3, type="ws", value=" "}
lexer:next() -- {start=4, stop=4, type="plus", value="+"}
lexer:next() -- {start=5, stop=5, type="ws", value=" "}
lexer:next() -- {start=6, stop=7, type="digit", value="15"}
lexer:next() -- nil: feed more/different data
```

As per the above example,
a return value of nil means that whatever follows is not a token.
It may mean end of input,
or merely that whatever follows isn't tokenizable with the given ruleset.
Here's an example of the latter:

```lua
lexer = patok {
	a = 'a',
	b = 'b',
}()
lexer.reset 'ac'
lexer:next() -- {start=1, stop=1, type='a', value='a'}
lexer:next() -- nil, even though we could still consume 'c'
```

### Parsing
If you just wanted a standalone lexer/tokenizer, that's all you need to know!
Most people, however, need a parser to go along with their lexer to make it useful.
Along with patok comes piecemeal:
a naive parser combinator made to work with patok.

Note that unlike patok, piecemeal is not particularly efficient,
nor capable of streaming input.
If you have a better patok-compatible option to use, please use that instead!
If you make such a parser, feel free to contact me at <toast+git@toast.cafe>,
I will add it to this section.

That said,
piecemeal is more than sufficient for many use-cases where lua itself is sufficient.
Please read the next section to find out how to use it.
(There will be no further information on patok itself for the rest of this file.)

## Piecemeal
Piecemeal is the default parser for patok.
If you have access to a different parser, chances are it will work better.

Piecemeal is a recursive descent parser combinator.
That means that you are provided with a set of parsing generating functions.
You compose and combine them into parsers, which you then compose and combine further.
The end result is a parser that parses your entire document on demand.

### Built-Ins
Piecemeal provides the following built-in functions:
* lexeme: lexeme looks for a "type" of token produced by patok
* value: value looks for an exact match of a token's text
* eof: only matches at the end of (lexed) input exactly once
* all: takes a list of parsers, producing a parser for all of them in a row
* alt: takes a list of parsers,
  producing a parser that looks for any one of its inputs (in order)
* opt: takes a parser and makes it optional
* plus: takes a parser and allows it to occur more than once in a row
  (it's the `+` operator in regex/PEG)
* star: equivalent to optional star (it's the `*` operator in regex/PEG)
* postp: takes a parser and a function, returns a parser
  whose output transforms the output of the input parser using the provided function

Finally, piecemeal provides the "parse" function, which takes the text to parse,
the patok (or api-compatible) lexer, and the parser to parse the text with.

This may be confusing,
so let's look through a commentated example.

### Example Grammar
This example grammar will be able to handle mathematic expressions.
For the sake of brevity, we'll only implement addition and multiplication.
Do know that you can extend this approach to cover all of math, however.

First, let's define our lexer.
```lua
lexer = patok {
	op  = '[+*]',
	num = '%d+',
	ws  = '%s+',
}()
```

We could have also made special lexemes for `+` and `*` individually.
However, this way, we can demonstrate both `pm.lexeme` and `pm.value`.

Let's prepare some lexing parsers ahead of time.
```lua
lex = {
	plus  = pm.value '+',
	star  = pm.value '*',
	digit = pm.postp(pm.lexeme 'digit', function (d) return tonumber(d.value) end),
	space = pm.opt(pm.lexeme 'space'),
}
```

In that snippet, there are two things to note.
First, we made the whitespace parser optional, as our grammar does not have significant whitespace.
Secondly, we used the potentially confusing `postp` function on digit.

Normally, a terminal parser (i.e `lexeme` and `value`) will return the bare token, as given to it by patok.
However, we generally don't want a huge layered list of tokens as the output.
Postp allows us to perform postprocessing operations on whatever data the input parser gives out.

In this case, we know the input data will be a patok token.
We're only really interested in the actual number, though.
So we return the numeric representation of the token.
We know it already looks like a number, because of our lexer pattern.
This means that other parsers that consume our digit parser will be able to simply work with digits.

To make this easier, we'll write a convenience function.
```lua
function findnums (d, acc)
	local out = acc or {}
	for _, v in ipairs(d) do
		if type(v) == 'number' then
			table.insert(out, v)
		elseif type(v) == 'table' then
			findnums(v, out)
		end
	end
	return out
end
```

A few things to note here.
First, note that we iterate over ipairs.
If we iterated over pairs, we would catch the start and end index of lexer tokens.
Secondly, note that we use the fact that tables are passed by reference in lua to allow for in-line accumulation.

Now that that's done, we can define our primary parsers.
The grammar looks something like so:
```
expr <- add
add <- mult ('+' mult)*
mult <- digit ('*' digit)*
```

This makes sure that multiplication happens before addition.
We can add subtraction and multiplication in-line by using alternatives for the signs, and switching on them in the postprocessing.

Let's implement mult first.
```lua
mult = pm.postp(
	pm.all(lex.digit, pm.star(pm.all(lex.space, lex.times, lex.space, lex.digit))),
	function (d)
		local acc = 1
		for _, v in ipairs(findnums(d)) do
			acc = acc * v
		end
		return acc
	end)
```

The parser component of the postprocessor is equivalent to the grammar above.
In the postprocessing function, we take advantage of the conveninece function we wrote.
We simply multiply all of the bare digits (which we know are consumed as a part of this sub-expression) together!
Importantly, we just return a number again, since that's what we're really interested in.

We can write add using the same method.
```lua
add = pm.postp(
	pm.all(mult, pm.star(pm.all(lex.space, lex.plus, lex.space, mult))),
	function (d)
		local acc = 0
		for _, v in ipairs(findnums(d)) do
			acc = acc + v
		end
		return acc
	end)
```

Note that we can use mult here directly - it's a valid parser like any other.

Finally, we can define expr, though it's technically optional.
```lua
expr = add
```

And now we can use the parser!
```lua
out, endindex, finalindex = pm.parse("10 + 5 * 2 + 10", lexer, expr) -- 14, 30
```

### Missing
In the above sample, we did not end up using the `alt` or `plus` generators.
`alt` is related to `all`.
Where `all` requires all of its arguments to succeed in order, `alt` will try them all in order, but only one has to succeed.
`plus` is related to `star`.
With `star`, zero matches are accepted.
`plus` works the same way, except at least one match is required.
