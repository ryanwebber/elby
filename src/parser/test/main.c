#include <stdio.h>

#include <elby/utils/vector.h>
#include "lex.h"
#include "parser.h"

char buf[32 + 1];

size_t get_id(struct ASTNode *node) {
    return (size_t) node;
}

void print_id(struct ASTNode *node) {
    printf("\tid_%ld [label = \"%s\"]\n", get_id(node), token_tosstring(node->root_token));
}

void print_edge(struct ASTNode *a_node, struct ASTNode *b_node) {
    printf("\tid_%ld -> id_%ld\n", get_id(a_node), get_id(b_node));
}

void visit(struct ASTNode *node, struct ASTVisitor *self) {
    print_id(node);
}

void visitBinOp(struct ASTNode *node, struct ASTVisitor *self) {
    print_edge(node, node->u.binop.left);
    print_edge(node, node->u.binop.right);
    ast_visit(self, node->u.binop.left);
    ast_visit(self, node->u.binop.right);
}

void visitUnaryOp(struct ASTNode *node, struct ASTVisitor *self) {
    print_edge(node, node->u.unop.left);
    ast_visit(self, node->u.unop.left);
}

void visitVarDef(struct ASTNode *node, struct ASTVisitor *self) {
    print_edge(node, node->u.var.expr);
    ast_visit(self, node->u.var.expr);
}

static struct ASTVisitor DOT_VISITOR = {
        .visit = visit,
        .visitVarDef = visitVarDef,
        .visitBinOp = visitBinOp,
        .visitUnaryOp = visitUnaryOp,
};

int main() {
    const char* source = "let a = 1 + 2 * 3 + 4 / -c";

    // LEX
    struct Lexer *lex = lexer_new(source);
    struct Vector *vec = vector_new(1);
    struct Token *tok;
    while (!lexer_next(lex, &tok) && tok->type != TOK_EOF) {
        vector_push(vec, tok);
    }

    if (!tok || tok->type != TOK_EOF) {
        fprintf(stderr, "Unexpected token\n");
        return 1;
    }

    // Include the EOF token
    vector_push(vec, tok);

    // Debug
    struct Token **tokens = vector_array(vec);
    for (int i = 0; i < vector_length(vec); i++) {
        token_tostring(tokens[i], buf, 32);
        buf[32] = '\0';
        printf("TOK %s\n", buf);
    }

    // PARSE
    struct ASTParse *ast;
    ast_parse(vector_array(vec), vector_length(vec), &ast);

    if (!ast)
        fprintf(stderr, "Error parsing AST\n");
    else {
        printf("digraph G {\n");
        ast_visit(&DOT_VISITOR, ast->root);
        printf("}\n");
    }

    ast_free(ast);

    // CLEANUP
    vector_free(vec);
    lexer_free(lex);
}
