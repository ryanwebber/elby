//
// Created by Ryan Webber on 5/19/20.
//

#ifndef ELBY_PARSER_H
#define ELBY_PARSER_H

#include <stddef.h>

#include "token.h"

enum ASTNodeType {
    AST_BINARY_OP,
    AST_CONSTANT,
    AST_EXPR_LIST,
    AST_FN_CALL,
    AST_FN_DEF,
    AST_REF,
    AST_STATEMENTS,
    AST_VAR
};

struct ASTNode {
    enum ASTNodeType type;
    struct Token *root_token;

    int id;

    union {

        struct {
            struct ASTNode *left;
            struct ASTNode *right;
            struct Token *op;
        } binop;

        struct {
            struct Token *value;
        } constant;

        struct {
            struct ASTNode *expr;
            struct ASTNode *next;
        } exprlist;

        struct {
            struct ASTNode *fnref;
            struct ASTNode *exprlist;
        } fncall;

        struct {
            struct ASTNode *body;
        } fndef;

        struct {
            struct Token *symbol;
        } ref;

        struct {
            struct ASTNode *statement;
            struct ASTNode *next;
        } statements;

        struct {
            struct Token *symbol;
            struct ASTNode *expr;
        } var;
    } u;
};

struct ASTParse {
    struct ASTNode *root;
};

struct ASTVisitor {
    void (*visit)(struct ASTNode*, struct ASTVisitor *self);
    void (*visitBinOp)(struct ASTNode*, struct ASTVisitor *self);
    void (*visitConstant)(struct ASTNode*, struct ASTVisitor *self);
    void (*visitExprList)(struct ASTNode*, struct ASTVisitor *self);
    void (*visitFnCall)(struct ASTNode*, struct ASTVisitor *self);
    void (*visitFnDef)(struct ASTNode*, struct ASTVisitor *self);
    void (*visitRef)(struct ASTNode*, struct ASTVisitor *self);
    void (*visitStatements)(struct ASTNode*, struct ASTVisitor *self);
    void (*visitVarDef)(struct ASTNode*, struct ASTVisitor *self);

    void *userdata;
};

/**
 * Parse the given tokens into an AST
 * @param token The array of tokens
 * @param len The number of tokens
 * @param stack The destination of the AST
 * @return
 */
int ast_parse(struct Token *tokens[], size_t len, struct ASTParse **parse);

/**
 * Free an ASTParse and associated AST nodes
 * @param stack
 */
void ast_free(struct ASTParse *parse);

/**
 * Visit a node in the AST
 * @param visitor The delegate visitor functions
 */
void ast_visit(struct ASTVisitor *visitor, struct ASTNode *node);

#endif //ELBY_PARSER_H
