const std = @import("std");
const main_module = @import("main.zig");
pub const RationalState2N = main_module.RationalState2N;

/// High-level audit wrapper ensuring that any sub-agent branch array slice 
/// is correctly handled, validated, and decomposed into zero-copy pointers 
/// before hitting foreign FFI execution gates.
pub fn verifyAgentTrajectoryTrace(
    state_envelope: RationalState2N,
    allocated_dimensions: usize,
    dt_num: i64,
    dt_den: i64,
    flat_router_weights: []const i64,
) i64 {
    // Enforce safety alignment boundaries before execution
    std.debug.assert(allocated_dimensions == 80);
    std.debug.assert(dt_den > 0);

    // Call the external shared object symbol compiled by PackageCompiler
    return compute_rational_leapfrog_step!(
        state_envelope,
        allocated_dimensions,
        dt_num,
        dt_den,
        flat_router_weights.ptr,
    );
}

// Bind directly back to the native library symbol mapping
extern fn compute_rational_leapfrog_step!(
    state: RationalState2N, 
    dim: usize, 
    dt_num: i64, 
    dt_den: i64, 
    weights_ptr: [*]const i64
) callconv(.C) i64;
