# julia/src/GeometricCage.jl
module GeometricCage

export MultiBranchCage, initialize_cage!, compute_branch_leapfrog_step!, setup_global_audit_arena

"""
Persistent matrix layout stored on the Julia heap.
Maintains un-rounded rational coordinates across an explicit 64-worker grid
to provide true multi-tenant parallel execution trajectory isolation.
"""
struct MultiBranchCage
    q_num::Matrix{Int64}
    q_den::Matrix{Int64}
    p_num::Matrix{Int64}
    p_den::Matrix{Int64}
end

# Global mutable pointer wrapper container to preserve arena states across FFI boundaries
const CAGE_RESERVOIR = Ref{MultiBranchCage}()

"""
    initialize_cage!(dim::Int, max_workers::Int=64)

Allocates isolated phase-space fields on the matrix substrate heap.
"""
function initialize_cage!(dim::Int, max_workers::Int=64)
    return MultiBranchCage(
        ones(Int64, dim, max_workers),          # q_num initialized to 1
        fill(Int64(10), dim, max_workers),      # q_den initialized to 10 (q = 1/10)
        zeros(Int64, dim, max_workers),         # p_num initialized to 0
        ones(Int64, dim, max_workers)           # p_den initialized to 1  (p = 0/1)
    )
end

Base.@ccallable function setup_global_audit_arena(dim::Csize_t)::Cint
    CAGE_RESERVOIR[] = initialize_cage!(Int(dim), 64)
    return Cint(0)
end

"""
    compute_branch_leapfrog_step!(worker_id::Csize_t, dim::Csize_t, dt_num::Int64, dt_den::Int64, weights_ptr::Ptr{Int64})::Int64

Executes an un-rounded Symplectic Leapfrog integration step over an isolated worker column slice.
Bypasses float micro-rounding drift completely via exact integer ratio cross-multiplication arithmetic.
"""
Base.@ccallable function compute_branch_leapfrog_step!(
    worker_id::Csize_t, 
    dim::Csize_t,
    dt_num::Int64,
    dt_den::Int64,
    weights_ptr::Ptr{Int64}
)::Int64

    N = Int(dim)
    # Convert 0-indexed worker_id from Zig to 1-indexed column pointer for Julia matrices
    w_idx = Int(worker_id) + 1 
    
    # Safely reference our global arena structures
    cage = CAGE_RESERVOIR[]
    
    # Map the connection tensor weights natively 
    W_matrix = unsafe_wrap(Array, weights_ptr, (N, N); own=false)
    
    # 1. POSITION HALF-STEP: q = q + (dt / 2) * p
    @inbounds for i in 1:N
        step_num = dt_num * cage.p_num[i, w_idx]
        step_den = dt_den * 2 * cage.p_den[i, w_idx]
        
        new_num = cage.q_num[i, w_idx] * step_den + step_num * cage.q_den[i, w_idx]
        new_den = cage.q_den[i, w_idx] * step_den
        
        g = gcd(new_num, new_den)
        cage.q_num[i, w_idx] = div(new_num, g)
        cage.q_den[i, w_idx] = div(new_den, g)
    end
    
    # 2. MOMENTUM FULL-STEP: p = p - dt * ∇W(q)
    drift_energy_num = 0
    @inbounds for i in 1:N
        grad_num = 0
        grad_den = 1
        
        # Exact linear combination computation: ∇W_i = Sum(W_ij * q_j)
        for j in 1:N
            term_num = W_matrix[i, j] * cage.q_num[j, w_idx]
            term_den = cage.q_den[j, w_idx]
            
            accum_num = grad_num * term_den + term_num * grad_den
            accum_den = grad_den * term_den
            
            g_term = gcd(accum_num, accum_den)
            grad_num = div(accum_num, g_term)
            grad_den = div(accum_den, g_term)
        end
        
        # Multiply by integration delta step: step = dt * grad
        step_num = dt_num * grad_num
        step_den = dt_den * grad_den
        
        # Inline subtraction from current p fraction vector
        new_p_num = cage.p_num[i, w_idx] * step_den - step_num * cage.p_den[i, w_idx]
        new_p_den = cage.p_den[i, w_idx] * step_den
        
        g_p = gcd(new_p_num, new_p_den)
        cage.p_num[i, w_idx] = div(new_p_num, g_p)
        cage.p_den[i, w_idx] = div(new_p_den, g_p)
        
        # Safely accumulate the exact scalar drift energy integer
        drift_energy_num += cage.p_num[i, w_idx]^2
    end
    
    # 3. POSITION FINAL HALF-STEP: q = q + (dt / 2) * p
    @inbounds for i in 1:N
        step_num = dt_num * cage.p_num[i, w_idx]
        step_den = dt_den * 2 * cage.p_den[i, w_idx]
        
        new_num = cage.q_num[i, w_idx] * step_den + step_num * cage.q_den[i, w_idx]
        new_den = cage.q_den[i, w_idx] * step_den
        
        g = gcd(new_num, new_den)
        cage.q_num[i, w_idx] = div(new_num, g)
        cage.q_den[i, w_idx] = div(new_den, g)
    end
    
    return drift_energy_num
end

end # module
