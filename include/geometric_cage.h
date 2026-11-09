#ifndef GEOMETRIC_CAGE_H
#define GEOMETRIC_CAGE_H

#include <stddef.h>
#include <stdint.h>

// Structurally aligned to mirror the exact un-rounded fraction vectors
typedef struct {
    int64_t* q_num_ptr;
    int64_t* q_den_ptr;
    int64_t* p_num_ptr;
    int64_t* p_den_ptr;
} RationalState2N;

// Production-grade C-ABI signature exported from libgeometric_cage.so
int64_t compute_rational_leapfrog_step!(RationalState2N state, size_t dim, int64_t dt_num, int64_t dt_den, int64_t* router_weights);

#endif
