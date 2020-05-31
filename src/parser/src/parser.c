//
// Created by Ryan Webber on 5/19/20.
//

#include <assert.h>
#include <stdio.h>
#include <stdbool.h>

#include "parser.h"

#define EXPECT(ip, type) token_guarantee(ip, type)

#define REJECT(ip) do {                                      \
    return ast_error_unexpected(ip, __FUNCTION__, NULL);     \
} while (0)

#define ACCEPT(ip, type, eat) do {                              \
    if (!token_try_accept(ip, type, eat))                           \
        return ast_error_unexpected(ip, __FUNCTION__, NULL);    \
} while (0)

#define PARSE_ERROR_BUF_LEN 255
static char parse_error_buf[PARSE_ERROR_BUF_LEN + 1] = { '\0' };

struct IntermediateParse {
    struct Token **all_tokens;
    struct Token *current_token;
    size_t token_offset;
    size_t token_count;

    int id;

    const char *error;
};

static struct ASTNode *parse_statements(struct IntermediateParse *ip);
static struct ASTNode *parse_expression(struct IntermediateParse *ip);

static bool end_of_statements(struct Token *tok) {
    switch (tok->type) {
        case TOK_EOF:
        case '}':
            return true;
        default:
            return false;
    }
}

static bool token_try_accept(struct IntermediateParse *ip, enum TokenType type, struct Token **ate) {
    if (ate)
        *ate = ip->current_token;

    if (ip->current_token->type == type) {
        printf("[parser] ate %s", token_tosstring(ip->current_token));
        ip->current_token = ip->all_tokens[++ip->token_offset];
        printf(", got %s\n", token_tosstring(ip->current_token));

        return true;
    } else {
        return false;
    }
}

static bool token_guarantee(struct IntermediateParse *ip, enum TokenType type) {
    assert(token_try_accept(ip, type, NULL));
    return true;
}

static struct ASTNode *ast_error_unexpected(struct IntermediateParse *ip, const char *rule, const char* expected) {
    char token_description[32 + 1];
    struct Token *tok = ip->current_token;
    token_tostring(tok, token_description, 32);
    token_description[32] = '\0';

    if (expected != NULL) {
        snprintf(parse_error_buf, PARSE_ERROR_BUF_LEN, "[%s] At %d: got unexpected %s (expected %s)",
                rule, tok->line_no, token_description, expected);
    } else {
        snprintf(parse_error_buf, PARSE_ERROR_BUF_LEN, "[%s] At %d: got unexpected %s",
                rule, tok->line_no, token_description);
    }

    parse_error_buf[PARSE_ERROR_BUF_LEN] = '\0';
    ip->error = parse_error_buf;

    return NULL;
}

static struct ASTNode *ast_new(struct IntermediateParse *ip, enum ASTNodeType type, struct Token *token) {
    struct ASTNode *ast_node = malloc(sizeof(struct ASTNode));
    ast_node->type = type;
    ast_node->root_token = token;
    ast_node->id = ip->id++;
    return ast_node;
}

static struct ASTNode *parse_number(struct IntermediateParse *ip) {
    struct ASTNode *node;
    struct Token *value;
    ACCEPT(ip, TOK_NUMBER, &value);
    node = ast_new(ip, AST_CONSTANT, value);
    node->u.ref.symbol = value;
    return node;
}

static struct ASTNode *parse_ref(struct IntermediateParse *ip) {
    struct ASTNode *node;
    struct Token *symbol;
    ACCEPT(ip, TOK_ID, &symbol);
    node = ast_new(ip, AST_REF, symbol);
    node->u.ref.symbol = symbol;

    return node;
}

static struct ASTNode *parse_function(struct IntermediateParse *ip) {
    struct Token *start;

    ACCEPT(ip, '{', &start);

    struct ASTNode *statements = parse_statements(ip);
    if (!statements)
        return NULL;

    ACCEPT(ip, '}', NULL);

    struct ASTNode *value = ast_new(ip, AST_FN_DEF, start);
    value->u.fndef.body = statements;

    return value;
}

static struct ASTNode *parse_primary(struct IntermediateParse *ip) {
    switch (ip->current_token->type) {
        case TOK_NUMBER:
            return parse_number(ip);
        case TOK_ID:
            return parse_ref(ip);
        case '{':
            return parse_function(ip);
        default:
            REJECT(ip);
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
    return parse_primary(ip);
}

static struct ASTNode *parse_exprlist(struct IntermediateParse *ip) {

    struct ASTNode *expr = parse_expression(ip);
    if (!expr)
        return NULL;

    struct ASTNode *exprnode = ast_new(ip, AST_EXPR_LIST, expr->root_token);
    exprnode->u.exprlist.expr = expr;
    exprnode->u.exprlist.next = NULL;

    if (ip->current_token->type != ')') {
        struct ASTNode *next = parse_exprlist(ip);
        if (!next)
            return NULL;

        exprnode->u.exprlist.next = next;
    }

    return exprnode;
}

static struct ASTNode *parse_call(struct IntermediateParse *ip) {
    struct Token *start;
    if (token_try_accept(ip, '(', &start)) {

        struct ASTNode *fn = parse_expression(ip);
        if (!fn)
            return NULL;

        struct ASTNode *args = NULL;
        if (ip->current_token->type != ')') {
            args = parse_exprlist(ip);
            if (!args)
                return NULL;
        }

        ACCEPT(ip, ')', NULL);

        struct ASTNode *fncall = ast_new(ip, AST_FN_CALL, start);
        fncall->u.fncall.fnref = fn;
        fncall->u.fncall.exprlist = args;
        return fncall;
    }

    return parse_postfix(ip);
}

static struct ASTNode *parse_pipe(struct IntermediateParse *ip) {
    struct ASTNode *left = parse_call(ip);
    struct ASTNode *right = NULL;

    while (left && ip->current_token->type != TOK_EOF) {
        struct Token *op = ip->current_token;

        switch (op->type) {
            case TOK_PIPE:
                EXPECT(ip, TOK_PIPE);
                break;
            default:
                return left;
        }

        right = parse_call(ip);
        if (!right)
            return NULL;

        struct ASTNode *node = ast_new(ip, AST_BINARY_OP, op);
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
    return parse_pipe(ip);
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
 *           ;
 * ```
 *
 * @param ip
 * @return
 */
static struct ASTNode *parse_statement(struct IntermediateParse *ip) {
    struct Token *token = ip->current_token;
    switch (token->type) {
        case TOK_LET: {
            struct Token *sym;
            EXPECT(ip, TOK_LET);
            ACCEPT(ip, TOK_ID, &sym);
            ACCEPT(ip, '=', NULL);

            struct ASTNode *exprnode = parse_expression(ip);
            if (!exprnode)
                return NULL;

            struct ASTNode *node = ast_new(ip, AST_VAR, sym);
            node->u.var.symbol = sym;
            node->u.var.expr = exprnode;
            return node;
        }
        default:
            return parse_expression(ip);
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

    struct ASTNode *statements = ast_new(ip, AST_STATEMENTS, ip->current_token);
    struct ASTNode *tail = statements;

    while (!end_of_statements(ip->current_token)) {
        struct ASTNode *statement_expr = parse_statement(ip);
        if (!statement_expr)
            return NULL;

        tail->u.statements.statement = statement_expr;
        tail->u.statements.next = ast_new(ip, AST_STATEMENTS, ip->current_token);
        tail = tail->u.statements.next;
    }

    // Sentinel
    tail->u.statements.statement = NULL;
    tail->u.statements.next = NULL;

    return statements;
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
            .id = 0,
            .error = NULL
    };

    struct ASTNode *root = parse_program(&ip);
    if (root == NULL || ip.error != NULL) {
        fprintf(stderr, "ERROR %s\n", ip.error);
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
        case AST_EXPR_LIST:
            if (visitor->visitExprList)
                visitor->visitExprList(node, visitor);
            break;
        case AST_FN_CALL:
            if (visitor->visitFnCall)
                visitor->visitFnCall(node, visitor);
            break;
        case AST_FN_DEF:
            if (visitor->visitFnDef)
                visitor->visitFnDef(node, visitor);
            break;
        case AST_REF:
            if (visitor->visitRef)
                visitor->visitRef(node, visitor);
            break;
        case AST_STATEMENTS:
            if (visitor->visitStatements)
                visitor->visitStatements(node, visitor);
            break;
        case AST_VAR:
            if (visitor->visitVarDef)
                visitor->visitVarDef(node, visitor);
            break;
        default:
            assert(0);
    }
}
