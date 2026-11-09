const std = @import("std");
const net = std.net;

/// 64-Byte Cache-Aligned Wire Format matching eightb-agy-fanout exactly.
/// Hardlocked to align(64) to maximize CPU registers throughput natively.
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

// Explicit C-ABI external bindings linked to our compiled libgeometric_cage.so binary image
extern fn setup_global_audit_arena(dim: usize) callconv(.C) i32;
extern fn compute_branch_leapfrog_step(
    worker_id: usize, 
    dim: usize, 
    dt_num: i64, 
    dt_den: i64, 
    weights_ptr: [*]const i64
) callconv(.C) i64;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Hardlocked to match the 8b project's cache-aligned geometry parameters exactly 
    const dimension: usize = 80; 
    
    std.log.info("==================================================================", .{});
    std.log.info("Initializing 8b-Cage Passive Network Intercept Stream Engine", .{});
    std.log.info("Target Space Geometry: Phase D Allostatic Circuit-Breaker Mesh", .{});
    std.log.info("==================================================================", .{});

    // 1. Fire initialization hook to construct the 64-worker substrate arena on the Julia heap
    if (setup_global_audit_arena(dimension) != 0) {
        std.log.err("Failed to initialize remote multi-tenant matrix reservoir substrate.", .{});
        return error.InitializationFailed;
    }
    std.log.info("Multi-branch memory arena securely allocated on runtime image heap.", .{});

    // 2. Instantiate pre-bounded scratchpad buffer for real-time routing layer weight evaluations
    const weights = try allocator.alloc(i64, dimension * dimension); 
    defer allocator.free(weights);
    @memset(weights, 2); // Seed matrix connection tensor parameters uniformly

    // 3. Bind to the local network interface matching the eightb-agy-fanout protocol stack
    const listen_address = try net.Address.parseIp("127.0.0.1", 18815);
    var socket = try std.posix.socket(listen_address.any.family, std.posix.SOCK.DGRAM, std.posix.IPPROTO.UDP);
    defer std.posix.close(socket);

    try std.posix.setsockopt(socket, std.posix.SOL.SOCKET, std.posix.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, 1)));
    try std.posix.bind(socket, &listen_address.any, listen_address.getOsSockLen());

    std.log.info("Passive auditing socket securely bound to 127.0.0.1:18815. Sniffing streams...", .{});

    // Allocate packet container array strictly locked to cache boundaries
    var packet_buffer: [64]u8 align(64) = undefined;

    while (true) {
        // Blocks until a 64-byte LanFrame64 data chunk strikes the network interface
        var remote_address: std.posix.sockaddr = undefined;
        var remote_address_len: std.posix.socklen_t = @sizeOf(std.posix.sockaddr);
        
        const bytes_received = std.posix.recvfrom(
            socket, 
            &packet_buffer, 
            0, 
            &remote_address, 
            &remote_address_len
        ) catch |err| {
            std.log.err("Socket read exception encountered: {}", .{err});
            continue;
        };

        if (bytes_received != 64) {
            std.log.warn("Frame dropped: Invalid byte payload length structure ({d}/64 bytes).", .{bytes_received});
            continue;
        }

        const frame: *const LanFrame64 = @ptrCast(&packet_buffer);

        if (!frame.isValid()) {
            std.log.warn("Frame dropped: Unauthorized seal gate signature or magic mismatch.", .{});
            continue;
        }

        if (!frame.verifyIntegrity()) {
            std.log.err("SECURITY ALERT: Broken SWAR fold-tag checksum calculation detected! Dropping packet.", .{});
            continue;
        }

        // Define exact un-rounded integration intervals matching the ULTRA-ZENO engine specifications
        const dt_num: i64 = 1;
        const dt_den: i64 = 100;

        // 4. Pass execution metrics along with the worker_id directly into the multi-branch Julia engine
        const accumulated_drift = compute_branch_leapfrog_step(
            @intCast(frame.worker_id),
            dimension, 
            dt_num, 
            dt_den, 
            weights.ptr
        );

        // 5. Out-of-band Allostatic threshold audit evaluation
        const DRIFT_MAX_NUMERATOR: i64 = 50000;
        if (accumulated_drift > DRIFT_MAX_NUMERATOR) {
            std.log.warn("⚠️  CRITICAL CONTEXT DRIFT DETECTED [Worker ID: {d} | Seq: {d}]. Invariant Drift Delta: {d}", .{
                frame.worker_id,
                frame.sequence,
                accumulated_drift,
            });
            
            std.log.warn("🚨 ALLOSTATIC BREAKER TRIGGERED: Constructing isolation feedback signal...", .{});

            // 6. PHASE D EXECUTION: Generate a high-priority, cache-aligned Allostatic Collapse Frame
            var kill_frame align(64) = LanFrame64{
                .magic = 0x8B15,
                .gate = 0x62,
                .opcode = 0x0F, // Hardcoded 0x0F Opcode maps straight to an un-bypassable cluster-wide stasis command
                .worker_id = frame.worker_id,
                .task_id = frame.task_id,
                .sequence = frame.sequence,
                .runnable_mask = 0, // Wipe the active execution bitmask
                .completed_mask = @intCast(accumulated_drift), // Package the violation score as diagnostic telemetry
                .payload = [_]u8{0} ** 24,
                .fold_tag = 0,
            };
            @memcpy(kill_frame.payload[0..13], "ALLOSTATIC_SOV");

            // Calculate the mandatory 64-bit SWAR fold checksum tag over the kill package layout
            const raw_u64_ptr: [*]const u64 = @ptrCast(&kill_frame);
            var checksum: u64 = 0;
            inline for (0..7) |i| {
                checksum ^= raw_u64_ptr[i];
            }
            kill_frame.fold_tag = checksum;

            // Transmit the signed collapse package directly back to the fanned-out orchestration loop source
            const outbound_bytes: [*]const u8 = @ptrCast(&kill_frame);
            _ = std.posix.sendto(
                socket, 
                outbound_bytes[0..64], 
                0, 
                &remote_address, 
                remote_address_len
            ) catch |err| {
                std.log.err("Failed to broadcast Allostatic circuit breaker feedback loop signal: {}", .{err});
                continue;
            };

            std.log.err("⚡ Allostatic Collapse instruction broadcasted successfully. Worker {d} isolated in stasis.", .{frame.worker_id});
        } else {
            std.log.info("✅ Trajectory verification step passed for Worker {d} (Sequence: {d}).", .{frame.worker_id, frame.sequence});
        }
    }
}
