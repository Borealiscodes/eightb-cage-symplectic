# julia/src/GeometricCage.jl
module GeometricCage

export RationalState2N, compute_rational_leapfrog_step!

"""
C-Compatible layout matching the 8b Project's exact p/q rational infrastructure.
Instead of floating-point arrays, coordinates are stored as paired integer numerators 
and denominators to achieve zero micro-rounding drift.
"""
struct RationalState2N
    q_num_ptr::Ptr{Int64}  # Intent numerators (Dimension N)
    q_den_ptr::Ptr{Int64}  # Intent denominators (Dimension N)
    p_num_ptr::Ptr{Int64}  # Context/Momentum numerators (Dimension N)
    p_den_ptr::Ptr{Int64}  # Context/Momentum denominators (Dimension N)
end

"""
    compute_rational_leapfrog_step!(state::RationalState2N, dim::Csize_t, dt_num::Int64, dt_den::Int64, weights_ptr::Ptr{Int64})::Int64

Executes an exact, un-rounded Symplectic Leapfrog integration step across the 2N manifold.
Operates natively on Zig-allocated integer buffers with machine precision.
Returns the integer numerator of the drift energy (normalized against the global denominator).
"""
Base.@ccallable function compute_rational_leapfrog_step!(
    state::RationalState2N, 
    dim::Csize_t,
    dt_num::Int64,
    dt_den::Int64,
    weights_ptr::Ptr{Int64}
)::Int64

    N = Int(dim)
    
    # Map the un-rounded integer coordinate arrays directly across the C-ABI
    q_num = unsafe_wrap(Array, state.q_num_ptr, N; own=false)
    q_den = unsafe_wrap(Array, state.q_den_ptr, N; own=false)
    p_num = unsafe_wrap(Array, state.p_num_ptr, N; own=false)
    p_den = unsafe_wrap(Array, state.p_den_ptr, N; own=false)
    W_matrix = unsafe_wrap(Array, weights_ptr, (N, N); own=false)
    
    # 1. POSITION HALF-STEP: q = q + (dt / 2) * p
    # Evaluated via exact cross-multiplication fraction arithmetic
    @inbounds for i in 1:N
        # dt/2 multiplication
        step_num = dt_num * p_num[i]
        step_den = dt_den * 2 * p_den[i]
        
        # Add to current q fraction: num/den = (q_num/q_den) + (step_num/step_den)
        new_num = q_num[i] * step_den + step_num * q_den[i]
        new_den = q_den[i] * step_den
        
        # Simplify fraction using Greatest Common Divisor to prevent integer overflow
        g = gcd(new_num, new_den)
        q_num[i] = div(new_num, g)
        q_den[i] = div(new_den, g)
    end
    
    # 2. MOMENTUM FULL-STEP: p = p - dt * ∇W(q)
    # The gradient is derived from the un-rounded router weight matrix
    drift_energy_num = 0
    @inbounds for i in 1:N
        grad_num = 0
        grad_den = 1
        
        # Compute exact linear combination: ∇W_i = Sum(W_ij * q_j)
        for j in 1:N
            term_num = W_matrix[i, j] * q_num[j]
            term_den = q_den[j]
            
            grad_num = grad_num * term_term_den + term_num * grad_den
            grad_den = grad_den * term_den
            g_term = gcd(grad_num, grad_den)
            grad_num = div(grad_num, g_term)
            grad_den = div(grad_den, g_term)
        end
        
        # Multiply by dt: step = dt * grad
        step_num = dt_num * grad_num
        step_den = dt_den * grad_den
        
        # Subtract from current p fraction
        new_p_num = p_num[i] * step_den - step_num * p_p_den[i]
        new_p_den = p_den[i] * step_den
        
        g_p = gcd(new_p_num, new_p_den)
        p_num[i] = div(new_p_num, g_p)
        p_den[i] = div(new_p_den, g_p)
        
        # Accumulate exact drift energy scalar
        drift_energy_num += div(new_p_num, g_p)^2
    end
    
    # 3. POSITION FINAL HALF-STEP: q = q + (dt / 2) * p
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
