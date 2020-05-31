//
// Created by Ryan Webber on 5/18/20.
//

#include <ctype.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#include "lex.h"

#define NL '\n'

struct KeywordToken {
    const char *kwd;
    const enum TokenType type;
};

struct ComplexToken {
    const char *token;
    size_t size;
    enum TokenType type;
};

static struct KeywordToken keywords[] = {
        { "let",        TOK_LET },
        { 0,            0 }
};

static struct ComplexToken complex_pipe[] = {
        { "|>",     2,         TOK_PIPE },
        { NULL,     0,         0  }
};

static struct ComplexToken complex_equals[] = {
        { "=>",     2,         TOK_ARROW },
        { NULL,     0,         0  }
};

/**
 * Determines if the character is a valid id character
 * @param c
 * @return
 */
bool is_identifier(char c) {
    return isalnum(c) || c == '_';
}

/**
 * Get the token type of the string value. If it's a keyword,
 * return the appropriate one, otherwise return an ID
 * @param value
 * @param len
 * @return
 */
enum TokenType type_for_id(const char *value, size_t len) {
    struct KeywordToken *keyword = keywords;
    while (keyword->kwd) {
        if (strncmp(keyword->kwd, value, len) == 0) {
            return keyword->type;
        }

        keyword++;
    }

    return TOK_ID;
}

/**
 * Fills in token data for a multi-char token.
 *
 * If none of the possibles match, a single-char
 * token will be created with the current char at
 * the head of the lexer
 *
 * @param lex
 * @param tok
 * @param possibles
 */
void assign_complex_token(struct Lexer *lex, struct Token *tok, struct ComplexToken *possibles) {
    const char *start = tok->start;
    while (possibles->token) {
        if (strncmp(start, possibles->token, possibles->size) == 0) {
            tok->type = possibles->type;
            tok->length = possibles->size;
            lex->position.index += possibles->size - 1;
            return;
        }

        possibles++;
    }

    tok->type = start[0];
    tok->length = 1;
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

    switch (tok_start) {

        // EOF
        case '\0':
            tok->type = TOK_EOF;
            tok->length = 0;
            break;

        // NUM
        case '0' ... '9': {
            lexer->partial.start = lexer->position.index - 1;
            lexer->partial.length = 1;
            while (isdigit(lexer_peek(lexer))) {
                lexer_advance(lexer);
                lexer->partial.length++;
            }

            char value[lexer->partial.length + 1];
            strncpy(value, lexer->partial.start, lexer->partial.length);
            value[lexer->partial.length] = '\0';

            tok->type = TOK_NUMBER;
            tok->length = lexer->partial.length;
            tok->u.number_value = atof(value);
            break;
        }

        // ID
        case 'a' ... 'z':
        case 'A' ... 'Z':
        case '_':
            lexer->partial.start = lexer->position.index - 1;
            lexer->partial.length = 1;
            while (is_identifier(lexer_peek(lexer))) {
                lexer_advance(lexer);
                lexer->partial.length++;
            }

            tok->type = type_for_id(lexer->partial.start, lexer->partial.length);
            tok->length = lexer->partial.length;
            tok->u.string_value = lexer->partial.start;
            break;

        // Multi char tokens
        case '|':
            assign_complex_token(lexer, tok, complex_pipe);
            break;
        case '=':
            assign_complex_token(lexer, tok, complex_equals);
            break;

        // Single char tokens
        case '{':
        case '}':
        case '(':
        case ')':
            tok->type = tok_start;
            tok->length = 1;
            break;

        // Unexpected char
        default:
            fprintf(stderr, "%d: Unexpected token '%c'\n", tok->line_no, tok_start);
            *dest = NULL;
            free(tok);
            return -1;
    }

    *dest = tok;
    return 0;
}
