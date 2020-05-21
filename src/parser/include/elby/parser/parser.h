//
// Created by Ryan Webber on 5/19/20.
//

#ifndef ELBY_PARSER_H
#define ELBY_PARSER_H

#include <stddef.h>

#include "token.h"

enum ASTNodeType {
    AST_VAR
};

struct ASTNode {
    enum ASTNodeType type;
    struct Token *root_token;

    union {
        struct {
            const char *name;
            struct ASTNode *expr;
        } var;
    } u;
};

struct ASTStack {
    struct ASTNode *node;
    struct ASTStack *next;
};

/**
 * Parse the given tokens into an AST
 * @param token The array of tokens
 * @param len The number of tokens
 * @param stack The destination of the AST
 * @return
 */
int ast_parse(struct Token *token[], size_t len, struct ASTStack **stack);

/**
 * Free an ASTStack
 * @param stack
 */
void ast_free(struct ASTStack *stack);

#endif //ELBY_PARSER_H
