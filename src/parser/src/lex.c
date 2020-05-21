//
// Created by Ryan Webber on 5/18/20.
//

#include <ctype.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

#include "lex.h"

#define NL '\n'

/**
 * Determines if the character is a valid id character
 * @param c
 * @return
 */
bool is_identifier(char c) {
    return isalnum(c) || c == '_';
}

/**
 * Advance the lexer, increment the line number if needed, and
 * return the consumed character
 * @param lex
 * @return The consumed character
 */
char lexer_advance(struct Lexer *lex) {
    char current = lex->position.index[0];

    if (current != '\0')
        lex->position.index++;

    if (current == NL)
        lex->position.line_no++;

    return current;
}

/**
 * Peek at the next character in the buffer without consuming it
 * @param lex
 * @return The next character
 */
char lexer_peek(struct Lexer *lex) {
    return *lex->position.index;
}

/**
 * Determine a match with either a single or double token
 *
 * Based on whether the next character in the buffer matches
 * the one provided, update the given token type and length.
 * If the token matches, the length is 2 and the type is the
 * one provided. If it doesn't, the length is 1 and we use
 * the raw token type as the token type.
 *
 * If the next character matches, we also consume it.
 *
 * @param lex
 * @param type The token type to use if the char does match
 * @param next The char to match against
 */
void lexer_switch_optional(
        struct Lexer *lexer,
        struct Token *tok,
        enum TokenType type,
        char next) {
   if (lexer_peek(lexer) == next) {
       tok->type = type;
       tok->length = 2;
       lexer_advance(lexer);
   } else {
       tok->type = lexer->position.index[-1];
       tok->length = 1;
   }
}

struct Lexer *lexer_new(const char *source) {
    struct Lexer *lexer = malloc(sizeof(struct Lexer));
    lexer->source = source;
    lexer->partial.start = source;
    lexer->partial.length = 0;
    lexer->position.index = source;
    lexer->position.line_no = 1;

    return lexer;
}

void lexer_free(struct Lexer *lexer) {
    free(lexer);
}

int lexer_next(struct Lexer *lexer, struct Token **dest) {

    struct Token *tok = malloc(sizeof(struct Token));
    char tok_start;

    do {
        tok_start = lexer_advance(lexer);
    } while (tok_start != '\0' && isspace(tok_start));

    tok->start = lexer->position.index - 1;
    tok->line_no = lexer->position.line_no;

    if (isnumber(tok_start)) {
        lexer->partial.start = lexer->position.index - 1;
        lexer->partial.length = 1;
        while (isnumber(lexer_peek(lexer))) {
            lexer_advance(lexer);
            lexer->partial.length++;
        }

        char value[lexer->partial.length + 1];
        strncpy(value, lexer->partial.start, lexer->partial.length);
        value[lexer->partial.length] = '\0';

        tok->type = TOK_NUMBER;
        tok->length = lexer->partial.length;
        tok->u.number_value = atof(value);

    } else if (isalpha(tok_start) || tok_start == '_') {
        lexer->partial.start = lexer->position.index - 1;
        lexer->partial.length = 1;
        while (is_identifier(lexer_peek(lexer))) {
            lexer_advance(lexer);
            lexer->partial.length++;
        }

        tok->type = token_keyword_or_id(lexer->partial.start, lexer->partial.length);
        tok->length = lexer->partial.length;
        tok->u.string_value = lexer->partial.start;

    } else {
        switch (tok_start) {
            case '\0':
                tok->type = TOK_EOF;
                tok->length = 0;
                break;
            case '{':
            case '}':
            case '(':
            case ')':
                tok->type = tok_start;
                tok->length = 1;
                break;
            case '=':
                lexer_switch_optional(lexer, tok,  TOK_EQUALITY, '=');
                break;
            default:
                *dest = NULL;
                free(tok);
                return -1;
        }
    }

    *dest = tok;
    return 0;
}
