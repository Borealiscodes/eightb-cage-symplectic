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

// 64-Byte Cache-Aligned Packet Footprint matching eightb-agy-fanout exactly
typedef struct __attribute__((aligned(64))) {
    uint16_t magic;           // 0x8B15 constellation magic
    uint8_t  gate;            // 0x62 Litany seal gate
    uint8_t  opcode;          // State change descriptor (Heartbeat, TaskDispatch, etc.)
    uint16_t worker_id;       // Target node index (0..63)
    uint16_t task_id;         // DAG task discriminant
    uint64_t sequence;        // Monotonic tap counter
    uint64_t runnable_mask;   // Active wave bitmask
    uint64_t completed_mask;  // Completed wave bitmask or Q15 rational affinity score
    uint8_t  payload[24];     // Inline model tag or telemetry matrix
    uint64_t fold_tag;        // 64-bit SWAR XOR-fold integrity check over bytes 0..56
} LanFrame64;

// Production FFI hook exported from libgeometric_cage.so
int64_t compute_rational_leapfrog_step!(RationalState2N state, size_t dim, int64_t dt_num, int64_t dt_den, int64_t* router_weights);

#endif
