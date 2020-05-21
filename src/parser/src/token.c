//
// Created by Ryan Webber on 5/19/20.
//

#include <stdio.h>
#include <string.h>

#include "token.h"

struct KeywordToken {
    const char *kwd;
    const enum TokenType type;
};

static struct KeywordToken keywords[] = {
        { "func",       TOK_FUNC },
        { "let",        TOK_LET },
        { 0,            TOK_EOF }
};

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
        case TOK_FUNC:
            snprintf(buf, len, "%s", "FUNC");
            break;
        default:
            snprintf(buf, len, "'%.*s'", tok->length, tok->start);
            break;
    }
}

enum TokenType token_keyword_or_id(const char *value, size_t len) {
    struct KeywordToken *keyword = keywords;
    while (keyword->kwd) {
        if (strncmp(keyword->kwd, value, len) == 0) {
            return keyword->type;
        }

        keyword++;
    }

    return TOK_ID;
}
