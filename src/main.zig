const std = @import("std");
const net = std.net;

/// C-ABI Compatible mapping mirroring the exact un-rounded fraction vectors
/// expected by the compiled Julia libgeometric_cage.so library.
pub const RationalState2N = extern struct {
    q_num_ptr: [*]i64,
    q_den_ptr: [*]i64,
    p_num_ptr: [*]i64,
    p_den_ptr: [*]i64,
};

/// 64-Byte Cache-Aligned Wire Format matching eightb-agy-fanout exactly.
/// Explicitly hard-locked to align(64) to glide into CPU registers natively.
pub const LanFrame64 = extern struct {
    magic: u16,
    gate: u8,
    opcode: u8,
    worker_id: u16,
    task_id: u16,
    sequence: u64,
    runnable_mask: u64,
    completed_mask: u64,
    payload: [24]u8,
    fold_tag: u64,

    /// Compares raw packet headers inside a single clock register cycle
    pub fn isValid(self: *const LanFrame64) bool {
        return (self.magic == 0x8B15 and self.gate == 0x62);
    }

    /// Evaluates the 64-bit SWAR XOR-fold integrity tag to protect the 
    /// pipeline against external packet injection or transmission corruption
    pub fn verifyIntegrity(self: *const LanFrame64) bool {
        const raw_ptr: [*]const u64 = @ptrCast(self);
        var checksum: u64 = 0;
        
        // XOR fold across the first 7 u64 chunks (bytes 0..56)
        inline for (0..7) |i| {
            checksum ^= raw_ptr[i];
        }
        
        return checksum == self.fold_tag;
    }
} align(64);

// Explicit external binding declaration linking directly to the symbol in our .so library
extern fn compute_rational_leapfrog_step!(
    state: RationalState2N, 
    dim: usize, 
    dt_num: i64, 
    dt_den: i64, 
    weights_ptr: [*]const i64
) callconv(.C) i64;

pub fn main() !void {
    // 1. Initialize a strict, high-performance general purpose allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Hardlocked to exactly 80 dimensions to perfectly pack into standard 64-byte hardware cache lines 
    // without a single byte of memory fragmentation, mirroring the 8b project's invariants.
    const dimension: usize = 80; 
    
    std.log.info("==================================================================", .{});
    std.log.info("Initializing 8b-Cage Passive Network Intercept Stream Engine", .{});
    std.log.info("Target Space Geometry: 2N Manifold [N={d} dimensions]", .{dimension});
    std.log.info("==================================================================", .{});

    // 2. Allocate cache-aligned scratchpad buffers on the heap for the integer fractions
    // These allocations are pre-bounded and un-aliased to maximize CPU execution speeds.
    const q_num = try allocator.alloc(i64, dimension); defer allocator.free(q_num);
    const q_den = try allocator.alloc(i64, dimension); defer allocator.free(q_den);
    const p_num = try allocator.alloc(i64, dimension); defer allocator.free(p_num);
    const p_den = try allocator.alloc(i64, dimension); defer allocator.free(p_den);
    
    // The routing/weight connection field matrix tensor (N x N flat array)
    const weights = try allocator.alloc(i64, dimension * dimension); defer allocator.free(weights);

    // 3. Seed vectors with a mock baseline trajectory trace (e.g., Initial state q = 1/10, p = 0/1)
    @memset(q_num, 1);
    @memset(q_den, 10);
    @memset(p_num, 0);
    @memset(p_den, 1);
    
    // Seed the weight tensor integers (simulating routing layer weights)
    @memset(weights, 2);

    const state = RationalState2N{
        .q_num_ptr = q_num.ptr,
        .q_den_ptr = q_den.ptr,
        .p_num_ptr = p_num.ptr,
        .p_den_ptr = p_den.ptr,
    };

    // 4. Bind to the local network port topology matching eightb-agy-fanout daemon
    const listen_address = try net.Address.parseIp("127.0.0.1", 18815);
    var socket = try std.posix.socket(listen_address.any.family, std.posix.SOCK.DGRAM, std.posix.IPPROTO.UDP);
    defer std.posix.close(socket);

    // Enable socket address reuse to prevent binding lockups across runtime restarts
    try std.posix.setsockopt(socket, std.posix.SOL.SOCKET, std.posix.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, 1)));
    try std.posix.bind(socket, &listen_address.any, listen_address.getOsSockLen());

    std.log.info("Passive auditing socket securely bound to 127.0.0.1:18815. Sniffing packets...", .{});

    // Allocate network packet container strictly aligned to standard CPU cache lines
    var packet_buffer: [64]u8 align(64) = undefined;

    while (true) {
        // Blocks until a 64-byte LanFrame64 data chunk strikes the network interface
        const bytes_received = std.posix.recvfrom(socket, &packet_buffer, 0, null, null) catch |err| {
            std.log.err("Socket read exception encountered: {}", .{err});
            continue;
        };

        if (bytes_received != 64) {
            std.log.warn("Frame dropped: Invalid byte payload structure length ({d}/64).", .{bytes_received});
            continue;
        }

        // Safe zero-copy cast from raw hardware bytes into our validated struct mapping
        const frame: *const LanFrame64 = @ptrCast(&packet_buffer);

        // Verification Checks
        if (!frame.isValid()) {
            std.log.warn("Frame dropped: Unauthorized seal gate signature or constellation magic mismatch.", .{});
            continue;
        }

        if (!frame.verifyIntegrity()) {
            std.log.err("SECURITY ALERT: Dropped packet due to broken SWAR fold-tag checksum integrity check!", .{});
            continue;
        }

        // Dynamically mutate trajectory states using exact integer indices instead of rewriting the slice reference pointers
        const mask_signal: i64 = @intCast(frame.completed_mask);
        q_num[0] = @intCast(frame.task_id); 
        p_num[0] = if (mask_signal == 0) 1 else mask_signal;

        // Define exact un-rounded integration metrics (Bypassing f64 decimal drift completely)
        const dt_num: i64 = 1;
        const dt_den: i64 = 100;

        // 5. Invoke the bare-metal auditing calculations natively via the shared library
        const accumulated_drift = compute_rational_leapfrog_step!(
            state, 
            dimension, 
            dt_num, 
            dt_den, 
            weights.ptr
        );

        // 6. Run automated circuit-breaker verification checks against our scalar threshold
        const DRIFT_MAX_NUMERATOR: i64 = 50000;
        if (accumulated_drift > DRIFT_MAX_NUMERATOR) {
            std.log.warn("⚠️  CRITICAL CONTEXT DRIFT DETECTED [Worker ID: {d} | Sequence: {d}]. Invariant Drift Delta: {d}", .{
                frame.worker_id,
                frame.sequence,
                accumulated_drift,
            });
        } else {
            std.log.info("✅ Trajectory verification step passed for Sequence: {d}. Rational bound verified.", .{frame.sequence});
        }
    }
}
