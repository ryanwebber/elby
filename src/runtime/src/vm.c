//
// Created by Ryan Webber on 5/30/20.
//

#include <stdio.h>
#include <assert.h>

#include "private/vm.h"

int vm_eval(struct VM *vm, const opcode *ops, size_t len) {
    for (size_t i = 0; i < len; i++) {
        opcode op = ops[i];

        size_t q;

        switch (OP_OPCODE(op)) {
            case OP_LOAD:
                q = OP_OPERAND_AB(op);
                printf("LOAD %ld\n", q);
                vm->s[vm->top++] = vm->v[q];
                break;
            case OP_STORE:
                q = OP_OPERAND_AB(op);
                printf("SET %ld\n", q);
                vm->v[q] = vm->s[--vm->top];
                break;
            case OP_PUSHI:
                q = OP_OPERAND_AB(op);
                printf("PUSHI %ld\n", q);
                vm->s[vm->top].type = VALUE_NUM;
                vm->s[vm->top].u.number = q;
                vm->top++;
                break;
            case OP_ADD:
                printf("ADD\n");
                vm->s[vm->top - 2].type = VALUE_NUM;
                vm->s[vm->top - 2].u.number = vm->s[vm->top - 1].u.number + vm->s[vm->top - 2].u.number;
                vm->top--;
                break;
            case OP_NOOP:
                printf("NOOP\n");
                break;
            default:
#if ELBY_STRICT
                fprintf(stderr, "Unknown opcode %d", op);
                assert(0);
#endif
                break;
        }
    }

    return 0;
}
