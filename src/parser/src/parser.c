//
// Created by Ryan Webber on 5/19/20.
//

#include "parser.h"

int ast_parse(struct Token *token[], size_t len, struct ASTStack **stack) {
    *stack = NULL;
    return 0;
}

void ast_free(struct ASTStack *stack) {
    if (stack == NULL)
        return;

    free(stack);
}
