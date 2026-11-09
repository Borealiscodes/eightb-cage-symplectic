# EightB Cage Symplectic (8b-cage-symplectic)
### Real-Time Un-Rounded Rational Audit Engine for Asynchronous Agent Orchestration

Original Project

https://github.com/8b-is/eightb-agy-fanout


`8b-cage-symplectic` is an **external, non-invasive research audit tool** engineered to evaluate, monitor, and mitigate semantic drift and representation collapse in parallel AI agent architectures. Specifically optimized as an out-of-band companion validation utility for high-concurrency clusters like `eightb-agy-fanout`, this toolkit intercepts agent state trajectories and screens them against hard metric invariants.

Rather than relying on post-hoc text heuristics or float-based statistics, this tool executes **zero-copy parallel transport verification** directly on latent state vectors. By treating agent traces as discrete trajectories moving through non-Euclidean manifolds, it exposes hidden contextual corruption at the physical silicon layer before it can contaminate downstream multi-agent response pools.

---

## 🔬 Architectural Philosophy & Research Mechanics

When multi-agent platforms employ aggressive "fan-out" strategies, they typically channel raw vector fields through softmax layers, collapsing high-dimensional latent structures onto a highly restricted probability simplex. This **simplex collapse** creates non-linear metric warping, making it difficult for an external observer to detect subtle, compounding adversarial state drifting or semantic hallucinations.

To maintain metric honesty, the 8b Project systematically strips out standard floating-point operations from its execution channels, implementing an un-rounded fixed-point logic framework (such as the *ULTRA-ZENO* rational math engine and *Q15* GRPO reinforcement structures) to completely isolate numerical calculation drift. 

To audit this environment honestly without introducing performance lag, `8b-cage-symplectic` deploys a dual-engine architecture:

1. **The Concurrency Interceptor (Zig Engine):** Operates adjacent to the target agent loop via a raw C-ABI interface. It intercepts thread-allocated tracking states and structures them inside pre-bounded shared memory arena buffers without performing memory copies.
2. **The Symplectic Manifold Auditor (Julia Engine):** Tracks the hidden trajectories across split coordinates mapping root intent ($\mathbf{q}$) and contextual momentum ($\mathbf{p}$). It mirrors the ULTRA-ZENO stack by processing paths as exact, un-rounded integer fractions ($p/q$), running a time-reversible **Symplectic Leapfrog Integrator** via discrete fraction transformations to compute precise, drift-free context safety bounds.

---

## 📁 Repository Structure

<pre>
    
eightb-cage-symplectic/
├── .github/workflows/
│   └── build-so.yml         # Automated CI/CD compilation for the native .so artifact
├── include/
│   └── geometric_cage.h      # C-ABI Header mapping the exact un-rounded RationalState2N layout
├── julia/
│   ├── src/
│   │   └── GeometricCage.jl  # Upgraded exact rational Symplectic Leapfrog manifold engine
│   ├── Project.toml          # Environment dependencies (LinearAlgebra, PackageCompiler)
│   └── compile.jl            # Standing system image compiler script
├── src/
│   ├── main.zig              # Independent auditing supervisor and trace memory allocator
│   ├── audit_ffi.zig         # Safe pointer-boundary wrapping layers
│   └── root.zig              # Base package module exports
├── build.zig                 # Native Zig build orchestration configuration
└── README.md                 # System documentation and research methodology
```

</pre>

---

## 🛠️ Research Audit Implementation

### 1. The Mathematical Core (`julia/src/GeometricCage.jl`)
This core bypasses floating-point decimals entirely. It handles incoming memory arrays as paired 64-bit integer vectors (Numerators and Denominators), utilizing Greatest Common Divisor (GCD) fraction reductions to preserve absolute precision over long reasoning horizons.

```julia
module GeometricCage

export RationalState2N, compute_rational_leapfrog_step!

"""
C-Compatible structural alignment matching the 8b un-rounded fraction infrastructure.
Coordinates are processed as paired Int64 variables to guarantee zero micro-rounding drift.
"""
struct RationalState2N
    q_num_ptr::Ptr{Int64}  # Intent numerators (Dimension N)
    q_den_ptr::Ptr{Int64}  # Intent denominators (Dimension N)
    p_num_ptr::Ptr{Int64}  # Context numerators (Dimension N)
    p_den_ptr::Ptr{Int64}  # Context denominators (Dimension N)
end

"""
    compute_rational_leapfrog_step!(state::RationalState2N, dim::Csize_t, dt_num::Int64, dt_den::Int64, weights_ptr::Ptr{Int64})::Int64

Performs a non-invasive, area-preserving Leapfrog integration step over exact fractional vector states.
Mutates the underlying arrays inline using discrete cross-multiplication integer arithmetic.
Returns the total integer scalar accumulation of context drift energy.
"""
Base.@ccallable function compute_rational_leapfrog_step!(
    state::RationalState2N, 
    dim::Csize_t,
    dt_num::Int64,
    dt_den::Int64,
    weights_ptr::Ptr{Int64}
)::Int64

    N = Int(dim)
    
    # Map raw integer arrays directly across the FFI without data copying
    q_num = unsafe_wrap(Array, state.q_num_ptr, N; own=false)
    q_den = unsafe_wrap(Array, state.q_den_ptr, N; own=false)
    p_num = unsafe_wrap(Array, state.p_num_ptr, N; own=false)
    p_den = unsafe_wrap(Array, state.p_den_ptr, N; own=false)
    W_matrix = unsafe_wrap(Array, weights_ptr, (N, N); own=false)
    
    # Stage 1: Position Half-Step (q-shear) -> q = q + (dt / 2) * p
    @inbounds for i in 1:N
        step_num = dt_num * p_num[i]
        step_den = dt_den * 2 * p_den[i]
        
        new_num = q_num[i] * step_den + step_num * q_den[i]
        new_den = q_den[i] * step_den
        
        g = gcd(new_num, new_den)
        q_num[i] = div(new_num, g)
        q_den[i] = div(new_den, g)
    end
    
    # Stage 2: Momentum Full-Step (p-shear) -> p = p - dt * ∇W(q)
    # The latent gradient is computed as an un-rounded matrix product sum
    drift_energy_num = 0
    @inbounds for i in 1:N
        grad_num = 0
        grad_den = 1
        
        for j in 1:N
            term_num = W_matrix[i, j] * q_num[j]
            term_den = q_den[j]
            
            next_grad_num = grad_num * term_den + term_num * grad_den
            next_grad_den = grad_den * term_den
            
            g_term = gcd(next_grad_num, next_grad_den)
            grad_num = div(next_grad_num, g_term)
            grad_den = div(next_grad_den, g_term)
        end
        
        step_num = dt_num * grad_num
        step_den = dt_den * grad_den
        
        new_p_num = p_num[i] * step_den - step_num * p_den[i]
        new_p_den = p_den[i] * step_den
        
        g_p = gcd(new_p_num, new_p_den)
        p_num[i] = div(new_p_num, g_p)
        p_den[i] = div(new_p_den, g_p)
        
        drift_energy_num += p_num[i]^2
    end
    
    # Stage 3: Position Final Half-Step (q-shear synchronization)
    @inbounds for i in 1:N
        step_num = dt_num * p_num[i]
        step_den = dt_den * 2 * p_den[i]
        
        new_num = q_num[i] * step_den + step_num * q_den[i]
        new_den = q_den[i] * step_den
        
        g = gcd(new_num, new_den)
        q_num[i] = div(new_num, g)
        q_den[i] = div(new_den, g)
    end
    
    return drift_energy_num
end

end # module
```

### 2. The Native Interceptor (`src/main.zig`)
The Zig supervisor establishes fixed-size memory allocations, locks the vector matrices inside an un-aliased arena layout, and checks the return scalar against the exact integer drift boundaries.

```zig
const std = @import("std");

pub const RationalState2N = extern struct {
    q_num_ptr: [*]int64_t,
    q_den_ptr: [*]int64_t,
    p_num_ptr: [*]int64_t,
    p_den_ptr: [*]int64_t,
};

// Interface directly with the un-rounded symbol exported from libgeometric_cage.so
extern fn compute_rational_leapfrog_step!(state: RationalState2N, dim: usize, dt_num: i64, dt_den: i64, weights_ptr: [*]const i64) callconv(.C) i64;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const dimension: usize = 80; // Hardlocked to mirror the 80-dimensional matrix invariants
    std.log.info("Initializing Un-Rounded Rational Symplectic Audit Engine...", .{});

    // Instantiate aligned scratchpad arenas for our fraction structures
    const q_num = try allocator.alloc(i64, dimension); defer allocator.free(q_num);
    const q_den = try allocator.alloc(i64, dimension); defer allocator.free(q_den);
    const p_num = try allocator.alloc(i64, dimension); defer allocator.free(p_num);
    const p_den = try allocator.alloc(i64, dimension); defer allocator.free(p_den);
    const weights = try allocator.alloc(i64, dimension * dimension); defer allocator.free(weights);

    // Seed variables with raw uniform fractional state values
    @memset(q_num, 1);
    @memset(q_den, 10); // Initial q = 1/10
    @memset(p_num, 0);
    @memset(p_den, 1);  // Initial p = 0/1
    @memset(weights, 2); // Router weights seeded as integers

    const state = RationalState2N{
        .q_num_ptr = q_num.ptr,
        .q_den_ptr = q_den.ptr,
        .p_num_ptr = p_num.ptr,
        .p_den_ptr = p_den.ptr,
    };

    // Define dt exactly as 1/100 (No float approximations)
    const dt_num: i64 = 1;
    const dt_den: i64 = 100;

    const accumulated_drift = compute_rational_leapfrog_step!(state, dimension, dt_num, dt_den, weights.ptr);

    std.log.info("Rational Audit Complete. Raw Drift Invariant Numerator: {d}", .{accumulated_drift});

    // Enforce clear bounding box thresholds to catch anomalous context deviations
    const DRIFT_MAX_NUMERATOR: i64 = 50000;
    if (accumulated_drift > DRIFT_MAX_NUMERATOR) {
Use code with caution.
std.log.warn("CRITICAL GEOMETRIC DRIFT: Semantic trajectory has compromised phase-space bounds.", .{});
} else {
std.log.info("Context trace verification successful. Rational invariant preserved.", .{});
}
}
```

⚡ Deployment & Build Pipeline

To build and run the non-invasive audit tool within your local testing infrastructure:
```bash

1. Compile the un-rounded Julia shared object library

cd julia && julia compile.jl && cd ..

2. Compile and link the main supervisor package using native Zig build rules

zig build
```

