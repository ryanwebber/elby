//
// Created by Ryan Webber on 5/19/20.
//

#include <assert.h>
#include <stdio.h>

#include "parser.h"

#define EXPECT_NEXT(ip, token_type, expected) do {  \
    if (token_next(ip)->type != token_type) {       \
        return ast_error_unexpected(ip, expected);  \
    }                                               \
} while (0)

#define EXPECT_CURRENT(ip, token_type) do {         \
    assert(ip->current_token->type == token_type);  \
} while (0)

#define PARSE_ERROR_BUF_LEN 255
static char parse_error_buf[PARSE_ERROR_BUF_LEN + 1] = { '\0' };

struct IntermediateParse {
    struct Token **all_tokens;
    struct Token *current_token;
    size_t token_offset;
    size_t token_count;

    const char *error;
};

static struct ASTNode *parse_statements(struct IntermediateParse *ip);

static struct Token* token_next(struct IntermediateParse *ip) {
    if (ip->token_offset >= ip->token_count) {
        printf("[parser] tokens exhausted\n");
        return NULL;
    }

    printf("[parser] ate %s", token_tosstring(ip->current_token));

    ip->current_token = ip->all_tokens[++ip->token_offset];

    printf(", got %s\n", token_tosstring(ip->current_token));

    return ip->current_token;
}

static struct Token* token_peek(struct IntermediateParse *ip) {
    if (ip->token_offset >= ip->token_count) {
        printf("[parser] tokens exhausted\n");
        return NULL;
    }

    return ip->all_tokens[ip->token_offset + 1];
}

static struct ASTNode *ast_error_unexpected(struct IntermediateParse *ip, const char* expected) {
    char token_description[32 + 1];
    struct Token *tok = ip->current_token;
    token_tostring(tok, token_description, 32);
    token_description[32] = '\0';

    if (expected != NULL) {
        snprintf(parse_error_buf, PARSE_ERROR_BUF_LEN, "At %d: got unexpected %s (expected %s)",
                tok->line_no, token_description, expected);
    } else {
        snprintf(parse_error_buf, PARSE_ERROR_BUF_LEN, "At %d: got unexpected %s",
                tok->line_no, token_description);
    }

    parse_error_buf[PARSE_ERROR_BUF_LEN] = '\0';
    ip->error = parse_error_buf;

    return NULL;
}

static struct ASTNode *ast_new(enum ASTNodeType type, struct Token *token) {
    struct ASTNode *ast_node = malloc(sizeof(struct ASTNode));
    ast_node->type = type;
    ast_node->root_token = token;
    return ast_node;
}

static struct ASTNode *parse_number(struct IntermediateParse *ip) {
    EXPECT_CURRENT(ip, TOK_NUMBER);
    struct ASTNode *node = ast_new(AST_CONSTANT, ip->current_token);
    node->u.constant.value = ip->current_token;
    return node;
}

static struct ASTNode *parse_ref(struct IntermediateParse *ip) {
    EXPECT_CURRENT(ip, TOK_ID);
    struct ASTNode *node = ast_new(AST_REF, ip->current_token);
    node->u.ref.symbol = ip->current_token;
    return node;
}

static struct ASTNode *parse_primary(struct IntermediateParse *ip) {
    switch (ip->current_token->type) {
        case TOK_NUMBER:
            return parse_number(ip);
        case TOK_ID:
            return parse_ref(ip);
        default:
            return NULL;
    }
}

/**
 * Parse a postfix operation
 *
 * ```
 * POSTFIX : PRIMARY
 *         ;
 * ```
 *
 * @param ip
 * @return
 */
static struct ASTNode *parse_postfix(struct IntermediateParse *ip) {
    struct ASTNode *left = parse_primary(ip);

    while (left) {
        if (left->type != AST_REF)
            return left;

        struct Token *next = token_peek(ip);
        switch (next->type) {
            default:
                return left;
        }
    }

    return left;
}

/**
 * Parse a prefix expression
 *
 * ```
 * PREFIX : POSTFIX
 *        | ! PREFIX
 *        | - PREFIX
 *        ;
 * ```
 *
 * @param ip
 * @return
 */
static struct ASTNode *parse_prefix(struct IntermediateParse *ip) {
    struct Token *op = ip->current_token;
    switch (op->type) {
        case '-':
        case '!':
            token_next(ip);
            struct ASTNode *left = parse_prefix(ip);
            if (!left)
                return NULL;

            struct ASTNode *node = ast_new(AST_UNARY_OP, op);
            node->u.unop.op = op;
            node->u.unop.left = left;
            return node;
        default:
            return parse_postfix(ip);
    }

    assert(0);
}

/**
 * Parse an multiplication expression
 *
 * ```
 * MULTIPLICATIVE : PREFIX
 *                | MULTIPLICATIVE + PREFIX
 *                | MULTIPLICATIVE - PREFIX
 *                ;
 * ```
 *
 * @param ip
 * @return
 */
static struct ASTNode *parse_infix_mult(struct IntermediateParse *ip) {
    struct ASTNode *left = parse_prefix(ip);
    struct ASTNode *right = NULL;

    while (left) {
        struct Token *op = token_peek(ip);
        switch(op->type) {
            case '/':
            case '*':
                token_next(ip);
                break;
            default:
                return left;
        }

        // Eat the operator
        token_next(ip);

        right = parse_prefix(ip);
        if (!right)
            return NULL;

        struct ASTNode *node = ast_new(AST_BINARY_OP, op);
        node->u.binop.left = left;
        node->u.binop.right = right;
        node->u.binop.op = op;

        left = node;
    }

    return left;
}

/**
 * Parse an addition expression
 *
 * ```
 * ADDITIVE : MULTIPLICATIVE
 *          | ADDITIVE + MULTIPLICATIVE
 *          | ADDITIVE - MULTIPLICATIVE
 *          ;
 * ```
 *
 * @param ip
 * @return
 */
static struct ASTNode *parse_infix_add(struct IntermediateParse *ip) {
    struct ASTNode *left = parse_infix_mult(ip);
    struct ASTNode *right = NULL;

    while (left) {
        struct Token *op = token_peek(ip);
        switch (op->type) {
            case '+':
            case '-':
                token_next(ip);
                break;
            default:
                return left;
        }

        // Eat the operator
        token_next(ip);

        right = parse_infix_mult(ip);
        if (!right)
            return NULL;

        struct ASTNode *node = ast_new(AST_BINARY_OP, op);
        node->u.binop.left = left;
        node->u.binop.right = right;
        node->u.binop.op = op;

        left = node;
    }

    return left;
}

/**
 * Parse an infix expression
 *
 * ```
 * INFIX : ADDITIVE
 *       ;
 * ```
 *
 * @param ip
 * @return
 */
static struct ASTNode *parse_infix(struct IntermediateParse *ip) {
    return parse_infix_add(ip);
}

/**
 * Parse an expression
 *
 * ```
 * EXPRESSION : INFIX
 *            ;
 * ```
 *
 * @param ip
 * @return
 */
static struct ASTNode *parse_expression(struct IntermediateParse *ip) {
    return parse_infix(ip);
}

/**
 * Parse statement
 *
 * ```
 * STATEMENT :
 *           | let ID = EXPRESSION
 *           | let ID = LAMBDA
 *           ;
 * ```
 *
 * @param ip
 * @return
 */
static struct ASTNode *parse_statement(struct IntermediateParse *ip) {
    struct Token *token = ip->current_token;
    switch (token->type) {
        case TOK_EOF: {
            struct ASTNode *node = ast_new(AST_STATEMENTS, token);
            node->u.statements.statements = NULL;
            node->u.statements.length = 0;
            return node;
        }
        case TOK_LET: {
            EXPECT_NEXT(ip, TOK_ID, "symbol");
            struct Token *sym = ip->current_token;

            EXPECT_NEXT(ip, '=', "=");

            token_next(ip);
            struct ASTNode *exprnode = parse_expression(ip);
            if (!exprnode)
                return NULL;

            struct ASTNode *node = ast_new(AST_VAR, sym);
            node->u.var.symbol = sym;
            node->u.var.expr = exprnode;
            return node;
        }
        default:
            return ast_error_unexpected(ip, NULL);
    }
}

/**
 * Parse statements
 *
 * ```
 * STATEMENTS :
 *            | STATEMENT
 *            | STATEMENT STATEMENTS
 *            ;
 * ```
 *
 * @param ip
 * @return
 */
static struct ASTNode *parse_statements(struct IntermediateParse *ip) {
    return parse_statement(ip);
}

/**
 * Parse the program
 *
 * ```
 * PROGRAM : STATEMENTS
 *         ;
 * ```
 *
 * @param ip
 * @return
 */
static struct ASTNode *parse_program(struct IntermediateParse *ip) {
    return parse_statements(ip);
}

int ast_parse(struct Token *tokens[], size_t len, struct ASTParse **parse) {
    struct IntermediateParse ip = {
            .all_tokens = tokens,
            .current_token = tokens[0],
            .token_offset = 0,
            .token_count = len,
            .error = NULL
    };

    struct ASTNode *root = parse_program(&ip);
    if (root == NULL || ip.error != NULL) {
        printf("[Error] %s", ip.error);
        *parse = NULL;
        return -1;
    } else {
        struct ASTParse *result_parse = malloc(sizeof(struct ASTParse));
        result_parse->root = root;
        *parse = result_parse;
        return 0;
    }
}

void ast_free(struct ASTParse *parse) {
    if (parse == NULL)
        return;

    free(parse);
}

void ast_visit(struct ASTVisitor *visitor, struct ASTNode *node) {
    if (!visitor || !node)
        return;

    if (visitor->visit)
        visitor->visit(node, visitor);

    switch (node->type) {
        case AST_BINARY_OP:
            if (visitor->visitBinOp)
                visitor->visitBinOp(node, visitor);
            break;
        case AST_CONSTANT:
            if (visitor->visitConstant)
                visitor->visitConstant(node, visitor);
            break;
        case AST_REF:
            if (visitor->visitRef)
                visitor->visitRef(node, visitor);
            break;
        case AST_STATEMENTS:
            if (visitor->visitStatements)
                visitor->visitStatements(node, visitor);
            break;
        case AST_UNARY_OP:
            if (visitor->visitUnaryOp)
                visitor->visitUnaryOp(node, visitor);
            break;
        case AST_VAR:
            if (visitor->visitVarDef)
                visitor->visitVarDef(node, visitor);
            break;
        default:
            assert(0);
    }
}
