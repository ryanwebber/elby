//
// Created by Ryan Webber on 5/29/20.
//

#ifndef ELBY_PRIVATE_VM_H
#define ELBY_PRIVATE_VM_H

#define ELBY_STACK_SIZE 32

#include "value.h"

struct Runtime {

    size_t stacktop;

    union {
        struct Value system[16];
        struct Value user[ELBY_STACK_SIZE];
    } stack;
};

#endif //ELBY_VM_H
