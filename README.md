# JuMag.jl

_A Julia package for classical spin dynamics and micromagnetic simulations with GPU support._

[![Docs latest](https://img.shields.io/badge/docs-latest-blue.svg)](https://ww1g11.github.io/JuMagDocs.jl/latest/)
[![Build Status](https://travis-ci.org/ww1g11/JuMag.jl.svg?branch=master)](https://travis-ci.org/ww1g11/JuMag.jl)
[![pipeline status](https://gitlab.com/JuliaGPU/JuMag.jl/badges/master/pipeline.svg)](https://gitlab.com/JuliaGPU/JuMag.jl/commits/master)
[![codecov](https://codecov.io/gl/ww1g11/JuMag.jl/branch/master/graph/badge.svg)](https://codecov.io/gl/ww1g11/JuMag.jl)


### Features

- Support classical spin dynamics and micromagnetic simulations.
- Support both CPU and GPU, which can be easily switched.
- Easily switch between single and double using `JuMag.cuda_using_double(false)`
- ...

## Installation

Install JuMag is straightforward as long as  Julia is installed, and it is equally easy in Windows, Linux and Mac.  



Requirements:

- Julia 1.4 (or above) (<http://julialang.org/downloads/>)
- Some packages such as FFTW, WriteVTK and NPZ
- CUDA.jl ([https://github.com/JuliaGPU/CUDA.jl](https://github.com/JuliaGPU/CUDA.jl)) (Needed for GPU support)

In [Julia](http://julialang.org), packages can be easily installed using

```
using Pkg;
Pkg.add("FFTW")
```
or

```
julia> ]
(v1.1) pkg> add FFTW
```

We don't have to install these packages for now, since the packages will be installed automatically when we install JuMag.
To install [JuMag.jl](https://github.com/ww1g11/JuMag.jl), simply using

```
(v1.1) pkg> add https://github.com/ww1g11/JuMag.jl
```

Now we will see similar messages if we type `using JuMag`

```
julia> using JuMag
[ Info: Precompiling JuMag [8b6b6816-cea2-582c-a99f-83810c20db0f]
┌ Warning: CUDA is not available!
└ @ JuMag ~/Softwares/JuMag.jl/src/JuMag.jl:41
```

### Note:

If your internet is very slow to install Julia packages, it is possible to solve the issue by using the Pkg mirrors

```
(v1.4) pkg> add PkgMirrors
julia> using PkgMirrors
julia> PkgMirrors.availables()
2-element Array{String,1}:
 "ZJU"
 "USTC"
julia> PkgMirrors.setmirror("USTC")
[ Info: PkgMirror USTC activated.
PkgMirrors.Types.PkgMirror("USTC", "https://mirrors.ustc.edu.cn/julia")
```

Alternatively,  running Julia in a Juno ([https://junolab.org/](https://junolab.org/)) terminal if you have a fast proxy.
