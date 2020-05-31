//
// Created by Ryan Webber on 5/29/20.
//

#ifndef ELBY_PRIVATE_VALUE_H
#define ELBY_PRIVATE_VALUE_H

#include <stdbool.h>
#include <stdint.h>

typedef uint32_t hashcode_t;

enum ValueType {
    VALUE_NULL = 0,
    VALUE_NUM,
    VALUE_BOOL,
    VALUE_STRING,
    VALUE_DICT,
    VALUE_ARR,
    VALUE_FN
};

struct Value {
    enum ValueType type;

    union {
       double number;
    } u;
};

hashcode_t value_hashcode(struct Value *value);
bool value_equals(struct Value *a, struct Value *b);

#endif //ELBY_PRIVATE_VALUE_H
