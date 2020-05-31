#include <stdio.h>
#include <stdlib.h>

#include "runtime.h"
#include "private/hashtable.h"
#include "private/runtime.h"
#include "private/vm.h"

elby_runtime *elby_new() {
    struct Runtime *runtime = malloc(sizeof(struct Runtime));
    runtime->stacktop = 0;

    return runtime;
}

void elby_close(elby_runtime *runtime) {
    free(runtime);
}

void elby_load(elby_runtime *runtime, const char *source) {
    printf("Evaluating: %s\n", source);
}

elby_error elby_call(elby_runtime *runtime, size_t nargs) {

    struct HashTable *ht = hashtable_new();

    for (int i = 0; i < 10; i++) {
        struct Value value = { VALUE_NUM, .u.number = i * 2 };

        printf("Inserting: %lf\n", value.u.number);
        hashtable_insert(ht, value, value);
    }

    for (int i = 0; i < 20; i++) {
        struct Value value = { VALUE_NUM, .u.number = i };

        printf("Checking: %lf... ", value.u.number);
        if (hashtable_lookup(ht, value, NULL)) {
            printf("Found!\n");
        } else {
            printf("Not found!\n");
        }
    }

    hashtable_free(ht);
    return 0;

    opcode program[] = {
            // Set 'a' to 15
            OP_ENCODE_AB(OP_PUSHI, 15),
            OP_ENCODE_AB(OP_STORE, 0),

            // Set 'c' to a + b
            OP_ENCODE_AB(OP_LOAD, 0),
            OP_ENCODE_AB(OP_LOAD, 1),
            OP_ENCODE_AB(OP_ADD, 0),
            OP_ENCODE_AB(OP_STORE, 2),
    };

    struct Value scope[] = {
            {
                .type = VALUE_NUM,
                .u.number = 20
            },
            {
                .type = VALUE_NUM,
                .u.number = 30
            },
            {
                .type = VALUE_NUM,
                .u.number = 40
            },
            {
                .type = VALUE_NULL,
            }
    };

    struct VM vm = { scope };

    vm_eval(&vm, program, 8);

    for (size_t i = 0; i < vm.top; i++) {
        printf("STACK %ld: %lf\n", i, vm.s[i].u.number);
    }

    for (size_t i = 0; i < 3; i++) {
        printf("VAR %ld: %lf\n", i, vm.v[i].u.number);
    }

    return 0;
}
