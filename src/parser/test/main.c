#include <stdio.h>

#include <elby/utils/vector.h>
#include "lex.h"
#include "parser.h"

char buf[32 + 1];

size_t get_id(struct ASTNode *node) {
    return (size_t) node->id;
}

void print_id(struct ASTNode *node) {
    printf("\tid_%ld [label = \"%s\"]\n", get_id(node), token_tosstring(node->root_token));
}

void print_edge(struct ASTNode *a_node, struct ASTNode *b_node, const char *description) {
    if (description)
        printf("\tid_%ld -> id_%ld [label = \"%s\"]\n", get_id(a_node), get_id(b_node), description);
    else
        printf("\tid_%ld -> id_%ld\n", get_id(a_node), get_id(b_node));
}

void visitBinOp(struct ASTNode *node, struct ASTVisitor *self) {
    print_id(node);
    print_edge(node, node->u.binop.left, NULL);
    print_edge(node, node->u.binop.right, NULL);

    ast_visit(self, node->u.binop.left);
    ast_visit(self, node->u.binop.right);
}

void visitVarDef(struct ASTNode *node, struct ASTVisitor *self) {
    print_id(node);
    print_edge(node, node->u.var.expr, "=");

    ast_visit(self, node->u.var.expr);
}

void visitFnCall(struct ASTNode *node, struct ASTVisitor *self) {
    print_id(node);
    print_edge(node, node->u.fncall.fnref, "fn");

    struct ASTNode *arg = node->u.fncall.exprlist;
    while (arg != NULL) {
        print_edge(node, arg->u.exprlist.expr, "arg");
        arg = arg->u.exprlist.next;
    }

    ast_visit(self, node->u.fncall.fnref);
    ast_visit(self, node->u.fncall.exprlist);

}

void visitExprList(struct ASTNode *node, struct ASTVisitor *self) {
    ast_visit(self, node->u.exprlist.next);
    ast_visit(self, node->u.exprlist.expr);
}

void visitConst(struct ASTNode *node, struct ASTVisitor *self) {
    print_id(node);
}

void visitRef(struct ASTNode *node, struct ASTVisitor *self) {
    print_id(node);
}

void visitStatements(struct ASTNode *node, struct ASTVisitor *self) {
    if (node->u.statements.statement) {
        print_id(node);
        print_edge(node, node->u.statements.statement, "stmt");
    }

    ast_visit(self, node->u.statements.statement);
    ast_visit(self, node->u.statements.next);
}

void visitFnDef(struct ASTNode *node, struct ASTVisitor *self) {
    print_id(node);
    print_edge(node, node->u.fndef.body, "body");

    ast_visit(self, node->u.fndef.body);
}

static struct ASTVisitor DOT_VISITOR = {
        .visitConstant = visitConst,
        .visitVarDef = visitVarDef,
        .visitBinOp = visitBinOp,
        .visitFnCall = visitFnCall,
        .visitFnDef = visitFnDef,
        .visitExprList = visitExprList,
        .visitRef = visitRef,
        .visitStatements = visitStatements,
};

int main() {
    const char *source = "let a = b |> { (add c) }\n"
                         "let b = ({ } a a)\n"
                         "let c = b\n"
                         "asdf asdf \n";

    // LEX
    struct Lexer *lex = lexer_new(source);
    struct Vector *vec = vector_new(1);
    struct Token *tok;
    while (!lexer_next(lex, &tok) && tok->type != TOK_EOF) {
        vector_push(vec, tok);
    }

    if (!tok || tok->type != TOK_EOF) {
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

    if (!ast) {
        fprintf(stderr, "Error parsing AST\n");
    } else {
        printf("digraph G {\n");
        printf("\tgraph [fontname = \"monospace\" ordering = out];\n");
        printf("\tnode [fontname = \"monospace\"];\n");
        printf("\tedge [fontname = \"monospace\"];\n");
        printf("\n");

        ast_visit(&DOT_VISITOR, ast->root);
        printf("}\n\n");
    }

//    CLEANUP
//    ast_free(ast);
//    vector_free(vec);
//    lexer_free(lex);
}
