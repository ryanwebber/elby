//
// Created by Ryan Webber on 5/18/20.
//

#ifndef ELBY_LEX_H
#define ELBY_LEX_H

#include <stdint.h>

#include "token.h"

struct Lexer {
    const char* source;

    struct {
        int line_no;
        const char* index;
    } position;

    struct {
        const char* start;
        int length;
    } partial;
};

/**
 * Create a new Lexer
 * @param source The source text to be lex'd
 * @return The new Lexer
 */
struct Lexer *lexer_new(const char *source);

/**
 * Free the Lexer and associated memory
 * @param lexer
 */
void lexer_free(struct Lexer *lexer);

/**
 * Parse the next token from the source
 * @param lexer
 * @param tok The token to be populated if successful
 * @return An error if unsuccessful
 */
int lexer_next(struct Lexer *lexer, struct Token **tok);

#endif //ELBY_LEX_H
