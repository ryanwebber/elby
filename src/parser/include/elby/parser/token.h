//
// Created by Ryan Webber on 5/19/20.
//

#ifndef ELBY_TOKEN_H
#define ELBY_TOKEN_H

#include <stdlib.h>

enum TokenType {
    // Control tokens
    TOK_EOF                     = -1,

    // Complex tokens
    TOK_ID                      = -1000,
    TOK_NUMBER                  = -1001,

    // Keywords
    TOK_FUNC                    = -2000,
    TOK_LET                     = -2020,

    // Condition operators
    TOK_EQUALITY                = -3000,
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
 * Get the token type of the string value. If it's a keyword,
 * return the appropriate one, otherwise return an ID
 * @param value
 * @param len
 * @return
 */
enum TokenType token_keyword_or_id(const char *value, size_t len);

#endif //ELBY_TOKEN_H
