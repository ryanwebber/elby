module.exports = grammar({
    name: 'elby',

    word: $ => $.identifier,

    extras: $ => [
        /\s/
    ],

    rules: {
        source_file: $ => repeat($._definition),

        _definition: $ => choice(
            $.function_definition
            // TODO: other kinds of definitions
        ),

        function_definition: $ => seq(
            'fn',
            field('name', $.identifier),
            field('parameters', $.parameter_list),
            field('return', optional(seq(
                '->',
                field('type', $._type),
            ))),
            field('body', $.block)
        ),

        parameter_list: $ => seq(
            '(',
            // TODO: parameters
            ')'
        ),

        _type: $ => choice(
            $.identifier,
        ),

        block: $ => seq(
            '{',
            repeat($._statement),
            '}'
        ),

        _statement: $ => choice(
            $.return_statement
            // TODO: other kinds of statements
        ),

        return_statement: $ => seq(
            'return',
            $._expression,
            ';'
        ),

        _expression: $ => choice(
            $.identifier,
            $.number
            // TODO: other kinds of expressions
        ),

        identifier: $ => /[a-zA-Z_]\w*/,

        number: $ => {
            const hex_literal = seq(
                choice('0x', '0X'),
                /[\da-fA-F]+/
            )

            const decimal_digits = /\d+/
            const signed_integer = seq(optional('-'), decimal_digits)
            const exponent_part = seq(choice('e', 'E'), signed_integer)

            const binary_literal = seq(choice('0b', '0B'), /[0-1]+/)

            const octal_literal = seq(choice('0o', '0O'), /[0-7]+/)

            const decimal_integer_literal = seq(
                optional(choice('-', '+')),
                choice(
                    '0',
                    seq(/[1-9]/, optional(decimal_digits))
                )
            )

            const decimal_literal = choice(
                seq(decimal_integer_literal, '.', optional(decimal_digits), optional(exponent_part)),
                seq('.', decimal_digits, optional(exponent_part)),
                seq(decimal_integer_literal, optional(exponent_part))
            )

            return token(choice(
                hex_literal,
                decimal_literal,
                binary_literal,
                octal_literal
            ))
        },
    }
});
