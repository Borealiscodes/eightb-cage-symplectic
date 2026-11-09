#ifndef GEOMETRIC_CAGE_H
#define GEOMETRIC_CAGE_H

#include <stddef.h>
#include <stdint.h>

/// 64-Byte Cache-Aligned Wire Format matching eightb-agy-fanout exactly.
/// Enforces #[repr(C, align(64))] byte-level structural matching.
typedef struct __attribute__((aligned(64))) {
    uint16_t magic;           // 0x8B15 constellation magic
    uint8_t  gate;            // 0x62 Litany seal gate
    uint8_t  opcode;          // State change descriptor (Heartbeat, TaskDispatch, etc.)
    uint16_t worker_id;       // Target node index (0..63)
    uint16_t task_id;         // DAG task discriminant
    uint64_t sequence;        // Monotonic tap counter
    uint64_t runnable_mask;   // Active wave bitmask
    uint64_t completed_mask;  // Completed wave bitmask or Q15 rational affinity score
    uint8_t  payload[24];     // 24-byte inline payload array
    uint64_t fold_tag;        // 64-bit SWAR XOR-fold integrity tag over bytes 0..56
} LanFrame64;

// Registration hook to instantiate the 64-worker substrate matrix on startup
int32_t setup_global_audit_arena(size_t dim);

// Upgraded C-compatible symbol mapping directly to libgeometric_cage.so
int64_t compute_branch_leapfrog_step(
    size_t worker_id, 
    size_t dim, 
    int64_t dt_num, 
    int64_t dt_den, 
    const int64_t* router_weights
);

#endif
