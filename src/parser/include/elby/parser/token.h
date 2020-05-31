//
// Created by Ryan Webber on 5/19/20.
//

#ifndef ELBY_TOKEN_H
#define ELBY_TOKEN_H

#include <stdlib.h>

enum TokenType {
    // Control tokens
    TOK_EOF                     = -1,

    // Associated tokens
    TOK_ID                      = -1000,
    TOK_NUMBER                  = -1001,

    // Keywords
    TOK_LET                     = -2000,

    // Operators
    TOK_PIPE                    = -3000,
    TOK_ARROW                   = -3001,
};

struct Token {
    enum TokenType type;

    const char* start;
    int length;
    int line_no;

    union {
        const char *string_value;
        double number_value;
    } u;
};

/**
 * Free the token. Does not free associated
 * string data.
 * @param tok
 */
void token_free(struct Token *tok);

/**
 * Copy a string value of the token into the buffer
 * @param tok
 * @param buf The destination buffer
 * @param len The length of the buffer
 */
void token_tostring(struct Token *tok, char *buf, size_t len);

/**
 * Return a string representation of the token
 * @param tok
 * @return The string representation of the token. Should
 * not be freed.
 */
const char* token_tosstring(struct Token *tok);

#endif //ELBY_TOKEN_H
