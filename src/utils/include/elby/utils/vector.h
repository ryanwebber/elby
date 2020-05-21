//
// Created by Ryan Webber on 5/20/20.
//

#ifndef ELBY_VECTOR_H
#define ELBY_VECTOR_H

#include <stddef.h>

struct Vector {
    struct {
        size_t capacity;
        size_t length;
    } header;

    void **elements;
};

struct Vector *vector_new(size_t capacity);
void vector_free(struct Vector *vector);

size_t vector_capacity(struct Vector *vector);
size_t vector_length(struct Vector *vector);

void *vector_push(struct Vector *vector, void *element);

void *vector_array(struct Vector *vector);

#endif //ELBY_VECTOR_H
