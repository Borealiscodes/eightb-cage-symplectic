using PackageCompiler

println("=== STARTING UN-ROUNDED RATIONAL COMPILATION ===")

create_sysimage(
    [:LinearAlgebra], 
    sysimage_path="libgeometric_cage.so",
    incremental=false,
    filter_stdlibs=true
)

println("=== COMPILATION COMPLETE. libgeometric_cage.so READY FOR ULTRA-ZENO HOOKS ===")
