//
// Created by Ryan Webber on 5/20/20.
//

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

#include "vector.h"

struct Vector *vector_new(size_t capacity) {
    struct Vector *vector = malloc(sizeof(struct Vector));
    vector->header.capacity = capacity;
    vector->header.length = 0;

    if (capacity > 0)
        vector->elements = calloc(capacity, sizeof(void*));
    else
        vector->elements = NULL;

    return vector;
}

void vector_free(struct Vector *vector) {
    free(vector);
}

size_t vector_capacity(struct Vector *vector) {
    return vector->header.capacity;
}

size_t vector_length(struct Vector *vector) {
    return vector->header.length;
}

void *vector_push(struct Vector *vector, void *element) {
    if (vector->header.length >= vector->header.capacity) {
        size_t new_capacity = vector->header.capacity < 2 ? 2 : vector->header.capacity * 2;
        vector->elements = realloc(vector->elements, new_capacity * sizeof(void*));
        vector->header.capacity = new_capacity;
    }

    assert(vector->header.capacity > vector->header.length);
    vector->elements[vector->header.length++] = element;
    return vector_array(vector);
}

void *vector_array(struct Vector *vector) {
    return vector->elements;
}
