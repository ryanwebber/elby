//
// Created by Ryan Webber on 5/31/20.
//

#include <stdlib.h>
#include <stdio.h>
#include <assert.h>

#include "private/hashtable.h"

struct HashBucket {
    hashcode_t hashcode;
    struct Value key;
    struct Value value;

    struct HashBucket *next;
};

struct HashTable {
    size_t size;
    size_t num_buckets;
    struct HashBucket **buckets;
};

struct HashTable *hashtable_new() {
    // Initial number of buckets
    size_t buckets = 8;

    struct HashTable *ht = malloc(sizeof(struct HashTable));
    ht->size = 0;
    ht->buckets = calloc(buckets, sizeof(void*));
    ht->num_buckets = buckets;

    return ht;
}

void hashtable_free(struct HashTable *ht) {
    if (ht->buckets != NULL)
        free(ht->buckets);

    free(ht);
}

size_t hashtable_size(struct HashTable *ht) {
    return ht->size;
}

void hashtable_insert(struct HashTable *ht, struct Value key, struct Value value) {
    hashcode_t hashcode = value_hashcode(&key);
    size_t idx = hashcode % ht->num_buckets;
    printf("%ld\n", idx);
    struct HashBucket *first = ht->buckets[idx];
    struct HashBucket *search_bucket = first;
    while (search_bucket != NULL) {
        if (search_bucket->hashcode == hashcode && value_equals(&key, &search_bucket->key)) {
            return;
        }

        search_bucket = search_bucket->next;
    }

    struct HashBucket *new_entry = malloc(sizeof(struct HashBucket));
    new_entry->hashcode = hashcode;
    new_entry->key = key;
    new_entry->value = value;
    new_entry->next = first;
    ht->buckets[idx] = new_entry;
    ht->size++;
}

int hashtable_lookup(struct HashTable *ht, struct Value key, struct Value *value) {
    hashcode_t hashcode = value_hashcode(&key);
    size_t idx = hashcode % ht->num_buckets;
    struct HashBucket *first = ht->buckets[idx];
    struct HashBucket *search_bucket = first;
    while (search_bucket != NULL) {
        if (search_bucket->hashcode == hashcode && value_equals(&key, &search_bucket->key)) {
            if (value)
                *value = search_bucket->value;

            return 1;
        }

        search_bucket = search_bucket->next;
    }

    return 0;
}
