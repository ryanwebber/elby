//
// Created by Ryan Webber on 5/19/20.
//

#include <stdio.h>
#include <string.h>

#include "token.h"

#define TOKEN_STRING_BUF_LEN 255
static char token_string_buf[TOKEN_STRING_BUF_LEN + 1];

void token_free(struct Token *tok) {
    free(tok);
}

void token_tostring(struct Token *tok, char *buf, size_t len) {
    switch (tok->type) {
        case TOK_EOF:
            snprintf(buf, len, "%s", "EOF");
            break;
        case TOK_ID:
            snprintf(buf, len, "ID(%.*s)", tok->length, tok->u.string_value);
            break;
        case TOK_NUMBER:
            snprintf(buf, len, "NUM(%lf)", tok->u.number_value);
            break;
        default:
            snprintf(buf, len, "'%.*s'", tok->length, tok->start);
            break;
    }
}

const char* token_tosstring(struct Token *tok) {
    token_tostring(tok, token_string_buf, TOKEN_STRING_BUF_LEN);
    token_string_buf[TOKEN_STRING_BUF_LEN] = '\0';
    return token_string_buf;
}
