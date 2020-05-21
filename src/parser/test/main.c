#include <stdio.h>

#include <elby/utils/vector.h>
#include "lex.h"
#include "parser.h"

int main() {
    const char* source = "let a = 0";

    // LEX
    struct Lexer *lex = lexer_new(source);
    struct Vector *vec = vector_new(1);
    struct Token *tok;
    while (!lexer_next(lex, &tok) && tok->type != TOK_EOF) {
        vector_push(vec, tok);
    }

    // PARSE
    struct ASTStack *ast;
    ast_parse(vector_array(vec), vector_length(vec), &ast);
    ast_free(ast);

    // DEBUG
    char buf[65];
    buf[64] = '\0';

    struct Token **tokens = vector_array(vec);
    for (int i = 0; i < vector_length(vec); i++) {
        token_tostring(tokens[i], buf, 64);
        printf("[%d] TOK %s\n", tokens[i]->line_no, buf);

        token_free(tokens[i]);
    }

    // CLEANUP
    vector_free(vec);
    lexer_free(lex);
}
