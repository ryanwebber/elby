//
// Created by Ryan Webber on 5/31/20.
//

#ifndef ELBY_HASHTABLE_H
#define ELBY_HASHTABLE_H

#include <stdint.h>
#include <stddef.h>

#include "value.h"

struct HashTable;

struct HashTable *hashtable_new();
void hashtable_free(struct HashTable *ht);

void hashtable_insert(struct HashTable *ht, struct Value key, struct Value value);
int hashtable_lookup(struct HashTable *ht, struct Value key, struct Value *value);

size_t hashtable_size(struct HashTable *ht);

#endif //ELBY_HASHTABLE_H
