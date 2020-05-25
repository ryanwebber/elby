//
// Created by Ryan Webber on 5/19/20.
//

#ifndef ELBY_PARSER_H
#define ELBY_PARSER_H

#include <stddef.h>

#include "token.h"

enum ASTNodeType {
    AST_BINARY_OP = 0,
    AST_CONSTANT,
    AST_REF,
    AST_STATEMENTS,
    AST_UNARY_OP,
    AST_VAR
};

struct ASTNode {
    enum ASTNodeType type;
    struct Token *root_token;

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
            struct Token *symbol;
        } ref;

        struct {
            struct ASTNode **statements;
            size_t length;
        } statements;

        struct {
            struct ASTNode *left;
            struct Token *op;
        } unop;

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
    void (*visitRef)(struct ASTNode*, struct ASTVisitor *self);
    void (*visitStatements)(struct ASTNode*, struct ASTVisitor *self);
    void (*visitUnaryOp)(struct ASTNode*, struct ASTVisitor *self);
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
