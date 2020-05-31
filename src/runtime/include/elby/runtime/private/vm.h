//
// Created by Ryan Webber on 5/30/20.
//

#ifndef ELBY_VM_H
#define ELBY_VM_H

#include <stddef.h>
#include <stdint.h>

#include "private/value.h"

#define OP_OPCODE(instr) (instr >> 10)
#define OP_OPERAND_A(instr) ((instr & 0x0300) >> 8)
#define OP_OPERAND_B(instr) (instr & 0x00FF)
#define OP_OPERAND_AB(instr) (instr & 0x03FF)
#define OP_ENCODE(instr, a, b) ((instr << 10) | ((a & 0x03) << 8) | (c & 0xff))
#define OP_ENCODE_AB(instr, ab) ((instr << 10) | ((ab & 0x03FF)))

typedef uint16_t opcode;

// Instruction: XXXX XXAA BBBB BBBB
enum op {
    OP_NOOP = 0x00,
    OP_LOAD,    // PUSH(V[AB])
    OP_STORE,   // V[AB] = POP()
    OP_PUSHI,   // PUSH(AB)
    OP_ADD,     // PUSH(POP() + POP())
};

struct VM {
    // Scope variables
    struct Value *v;

    // VM stack
    size_t top;
    struct Value s[32];
};

int vm_eval(struct VM *vm, const opcode *ops, size_t len);

#endif //ELBY_VM_H
