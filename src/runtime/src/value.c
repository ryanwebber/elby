//
// Created by Ryan Webber on 5/29/20.
//

#include <assert.h>
#include "private/value.h"

hashcode_t value_hashcode(struct Value *value) {
    switch (value->type) {
        case VALUE_NULL:
            return 0;
        case VALUE_NUM:
            return value->u.number;
        default:
            assert(0);
    }
}

bool value_equals(struct Value *a, struct Value *b) {
    switch (a->type) {
        case VALUE_NULL:
            return true;
        case VALUE_NUM:
            return a->u.number == b->u.number;
        default:
            assert(0);
    }
}
