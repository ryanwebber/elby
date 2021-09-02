# Elby Language

An embeddable pre-processor language exposing a `c` API.

## Features
 * Dynamic type system
 * Reference counting based GC
 * UTF-8 support
 * Multiple output formats

```
<html>
    <body>
        {$ // This is a comment inside a code block $}
        {$ // Code blocks are stripped from the output, including leading and trailing spaces $}
        {$
            // This is a code block
            let x = 5

            // Double braces perform output with the provided expression
            {{ x }}

            // TODO: Syntax to adjust output properties (mode, encoding, new line character, etc)
            {{ "" }}

            for let i in 0 .. 10 do
                if i % 2 == 0 do
                    // TODO: Syntax to adjust tabs and indentation
                    <li>
                        Even: {{ i }}
                    </li>
                    {{ "<li>Odd</li>" }}
                end
            end

            // Triple quotes evaluates the inner string (TODO: what about nested """ ?)
            let out =
                """
                <span>Hello {{ "World" }}</span>
                """

            // Can dump out the evaluated string
            {{ out }}

            // Can also use triple quoting to output little snippets
            {{ """<li>{{ out }}</li>""" }}

            // TODO: Short form for the above?
            {"<li>{{ out }}</li>"}
        $}
    </body>
</html>
```
