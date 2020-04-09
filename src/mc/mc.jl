using Random
using WriteVTK

function MonteCarloNew(mesh::Mesh; name="mc", mc_2d=false)
    Float = _cuda_using_double.x ? Float64 : Float32
    sim = MonteCarloNew{Float}()
    sim.mc_2d = mc_2d
    sim.mesh = mesh
    nxyz = mesh.nx*mesh.ny*mesh.nz
    sim.nxyz = nxyz

    sim.shape = CuArrays.ones(Bool, nxyz)
    sim.spin = CuArrays.zeros(Float, 3*nxyz)
    sim.nextspin = CuArrays.zeros(Float,3*nxyz)
    sim.rnd = CuArrays.zeros(Float,3*nxyz)
    sim.energy = CuArrays.zeros(Float,nxyz)
    sim.delta_E = CuArrays.zeros(Float,nxyz)
    sim.steps = 0
    sim.name = name
    sim.T = 300
    if isa(sim.mesh, CubicMeshGPU)
        sim.exch = ExchangeMC(CuArrays.zeros(Float, mesh.n_ngbs), CuArrays.zeros(Float, mesh.n_ngbs))
        sim.dmi = DMI_MC(CuArrays.zeros(Float, (3, mesh.n_ngbs)), CuArrays.zeros(Float, (3, mesh.n_ngbs)))
    else
        sim.exch = NearestExchangeMC(CuArrays.zeros(Float, mesh.n_ngbs))
        sim.dmi = Nearest_DMI_MC(CuArrays.zeros(Float, (3, mesh.n_ngbs)))
    end
    sim.zee = ZeemanMC(Float(0),Float(0),Float(0))
    sim.anis = UniformAnisotropyMC(Float(0),Float(0),Float(0),Float(1),Float(0))

    headers = ["step", "time", "E_total", ("m_x", "m_y", "m_z")]
    units = ["<>", "<s>", "<J>",("<>", "<>", "<>")]
    results = [o::AbstractSim -> o.saver.nsteps,
             o::AbstractSim -> o.saver.t,
             o::AbstractSim -> o.total_energy, average_m]
    saver = DataSaver(string(name, ".txt"), 0.0, 0, false, headers, units, results)
    sim.saver = saver

    return sim
end

function add_exch(sim::MonteCarloNew; J=1, J1=0)
    sim.exch.J .= J/k_B
    if isa(sim.mesh, CubicMeshGPU)
        sim.exch.J1 .= J1/k_B
    end
    return nothing
end

function add_exch(sim::MonteCarloNew, Jx, Jy, Jz, Jx1, Jy1, Jz1)
    mesh = sim.mesh
    cubic = isa(mesh, CubicMeshGPU) ? true : false

    T = _cuda_using_double.x ? Float64 : Float32
    Jx = Jx/k_B
    Jy = Jy/k_B
    Jz = Jz/k_B
    J = Array([T(Jx), T(Jx), T(Jy), T(Jy), T(Jz), T(Jz)])
    copyto!(exch.J, J)
    if cubic
        Jx1 = Jx1/k_B
        Jy1 = Jy1/k_B
        Jz1 = Jz1/k_B
        J1 = Array([T(Jx1), T(Jx1), T(Jy1), T(Jy1), T(Jz1), T(Jz1)])
        copyto!(exch.J1, J1)
    end
    return nothing
end

function add_dmi_cubic(sim::MonteCarloNew, Dx::Number, Dy::Number, Dz::Number, Dx1::Number, Dy1::Number, Dz1::Number, type::String)
    dmi = sim.dmi
    cubic = isa(sim.mesh, CubicMeshGPU) ? true : false
    if !cubic
        error("This function only works for CubicMeshGPU!")
    end
    T = _cuda_using_double.x ? Float64 : Float32
    Dx = Dx/k_B
    Dy = Dy/k_B
    Dz = Dz/k_B
    Dx1 = Dx1/k_B
    Dy1 = Dy1/k_B
    Dz1 = Dz1/k_B
    D = zeros(T, (3, 6))
    D1 = zeros(T, (3, 6))

    if type == "bulk"
        D[1, 1] = -Dx
        D[1, 2] = Dx
        D[2, 3] = -Dy
        D[2, 4] = Dy
        D[3, 5] = -Dz
        D[3, 6] = Dz

        D1[1, 1] = -Dx1
        D1[1, 2] = Dx1
        D1[2, 3] = -Dy1
        D1[2, 4] = Dy1
        D1[3, 5] = -Dz1
        D1[3, 6] = Dz1
    elseif type == "interfacial"
        D[1, 3] = -Dy
        D[1, 4] = Dy
        D[2, 1] = Dx
        D[2, 2] = -Dx

        D1[1, 3] = -Dy1
        D1[1, 4] = Dy1
        D1[2, 1] = Dx1
        D1[2, 2] = -Dx1
    end

    copyto!(dmi.D, D)
    copyto!(dmi.D1, D1)
    return nothing
end

function add_dmi_triangular(sim::MonteCarloNew, Dxy::Number, Dz::Number, type::String)
    dmi = sim.dmi
    T = _cuda_using_double.x ? Float64 : Float32
    Dxy = Dxy/k_B
    Dz = Dz/k_B

    D = [(1, 0, 0),
         (1/2, sqrt(3)/2, 0),
         (-1/2, sqrt(3)/2, 0),
         (-1, 0, 0),
         (-1/2, -sqrt(3)/2, 0),
         (-1/2, sqrt(3)/2, 0),
         (0,0,-1),
         (0,0,1)]

    DD = zeros(T, (3, 8))
    if type == "bulk"
        for i=1:8
            DD[:, i] .= D[i]
        end
    elseif type == "interfacial"
        for i=1:8
            DD[:, i] .= cross_product((0,0,1.0), D[i])
        end
    end
    DD *= Dxy
    copyto!(dmi.D, DD)
    return nothing
end

function add_dmi(sim::MonteCarloNew; D=1.0, D1=0.0, type="bulk")
    D = Float64(D)
    D1 = Float64(D1)
    if isa(sim.mesh, CubicMeshGPU)
        add_dmi_cubic(sim, D, D, D, D1, D1, D1, type)
    elseif isa(sim.mesh, TriangularMeshGPU)
        add_dmi_triangular(sim, D, D, type)
    end
    return nothing
end

#Hx, Hy, Hz in energy unit， just as J and D
function add_zeeman(sim::MonteCarloNew; Hx=0, Hy=0, Hz=0)
    zeeman = sim.zee
    zeeman.Hx = Hx/k_B
    zeeman.Hy = Hy/k_B
    zeeman.Hz = Hz/k_B
    return nothing
end

function update_zeeman(sim::MonteCarloNew; Hx=0, Hy=0, Hz=0)
    add_zeeman(sim, Hx=Hx, Hy=Hy, Hz=Hz)
    return nothing
end

function add_anis(sim::MonteCarloNew; Ku=1, Kc=0, axis=(0,0,1))
    anis = sim.anis
    anis.Ku = Ku/k_B
    length = sqrt(axis[1]^2+axis[2]^2+axis[3]^2)
    if length < 1e-15
        anis.uz  = 1.0
    else
        anis.ux = axis[1]/length
        anis.uy = axis[2]/length
        anis.uz = axis[3]/length
    end
    anis.Kc = Kc/k_B
    return nothing
end

"""
    add_anis_kagome(sim::MonteCarloNew, Ku::Float64)

Add Anisotropy for kagome system, where the energy density is given by

```math
    E_\\mathrm{anis} = - K_{u} (\\vec{m} \\cdot \\hat{u})^2
```
and u is one of ax1=(-0.5,-sqrt(3)/2,0), ax2=(1,0,0) and ax3=(-0.5,sqrt(3)/2,0).
"""
function add_anis_kagome(sim::MonteCarloNew; Ku=0)
  T = _cuda_using_double.x ? Float64 : Float32

  sim.anis = KagomeAnisotropyMC(T(0))
  sim.anis.Ku = Ku/k_B

  return nothing
end
function add_anis_kagome_6fold(sim::MonteCarloNew; K1=0,K2=0)
  T = _cuda_using_double.x ? Float64 : Float32

  sim.anis = KagomeAnisotropy6FoldMC(T(0),T(0))
  sim.anis.K1 = K1/k_B
  sim.anis.K2 = K2/k_B

  return nothing
end

function init_m0(sim::MonteCarloNew, m0::Any; norm=true)
  Float = _cuda_using_double.x ? Float64 : Float32
  spin = zeros(Float, 3*sim.nxyz)
  init_vector!(spin, sim.mesh, m0)
  if norm
    normalise(spin, sim.nxyz)
  end
  shape = Array(sim.shape)
  for i in 1:sim.nxyz
      if !shape[i]
          spin[3*i-2] = NaN32
          spin[3*i-1] = NaN32
          spin[3*i] = NaN32
      end
  end
  copyto!(sim.spin, spin)
  return true
end

function update_ngbs(mesh, shape::Array{Bool})
    ngbs = Array(mesh.ngbs)
    nngbs = Array(mesh.nngbs)
    for i = 1:mesh.nxyz
        for j=1:mesh.n_ngbs
            id = ngbs[j, i]
            if id>0 && ((!shape[id]) ||(!shape[i]))
                ngbs[j, i] = -1
            end

            id = nngbs[j, i]
            if id>0 && ((!shape[id]) ||(!shape[i]))
                nngbs[j, i] = -1
            end
        end
    end
    copyto!(mesh.ngbs, ngbs)
    copyto!(mesh.nngbs, nngbs)
    return nothing
end

function set_shape(sim::MonteCarloNew, fun_Ms::Function)
    mesh = sim.mesh
    shape = ones(Bool, mesh.nxyz)
    for k = 1:mesh.nz, j = 1:mesh.ny, i = 1:mesh.nx
        id = index(i, j, k, mesh.nx, mesh.ny, mesh.nz)
        shape[id] = fun_Ms(i, j, k, mesh.dx, mesh.dy, mesh.dz)
    end
    copyto!(sim.shape, shape)
    update_ngbs(sim.mesh, shape)
    return true
end

function set_shape_to_kagome(sim::MonteCarloNew)
    mesh = sim.mesh
    shape = ones(Bool, mesh.nxyz)
    for k = 1:mesh.nz, j = 1:mesh.ny, i = 1:mesh.nx
        id = index(i, j, k, mesh.nx, mesh.ny, mesh.nz)
        #shape[id] = true
        if i%2==0 && j%2==0
            shape[id] = false
        end
    end
    copyto!(sim.shape, shape)
    update_ngbs(sim.mesh, shape)
    return true
end

function run_step_cubic(sim::MonteCarloNew)
    if sim.mc_2d
        uniform_random_circle_xy(sim.nextspin, sim.rnd, sim.nxyz)
    else
        uniform_random_sphere(sim.nextspin, sim.rnd, sim.nxyz)
    end
    run_single_step(sim, 0, true)
    run_single_step(sim, 1, true)
    run_single_step(sim, 2, true)
    sim.steps += 1

    return  nothing
end

function run_step_triangular(sim::MonteCarloNew)

  uniform_random_sphere(sim.nextspin, sim.rnd, sim.nxyz)

  run_single_step(sim, 0, false)
  run_single_step(sim, 1, false)
  run_single_step(sim, 2, false)
  sim.steps += 1

  return  nothing
end


function run_single_step(sim::MonteCarloNew, bias::Int64, cubic::Bool)
    blk, thr = CuArrays.cudims(sim.nxyz)

    compute_site_energy_single(sim, bias, cubic)

    mesh = sim.mesh

    @cuda blocks=blk threads=thr  run_monte_carlo_kernel!(sim.spin, sim.nextspin, sim.rnd,
                                    sim.shape,
                                    sim.energy, sim.T,
                                    mesh.nx, mesh.ny, mesh.nz, bias, cubic)

  return nothing
end


function run_sim(sim::MonteCarloNew; maxsteps=10000, save_m_every = 10, save_vtk_every=-1, save_ovf_every=-1, ovf_format="binary8")
    cubic = isa(sim.mesh, CubicMeshGPU) ? true : false
    for i=1:maxsteps

        if save_m_every>0
            if sim.steps%save_m_every == 0
                energy = compute_system_energy(sim)
                @info @sprintf("step=%5d  total_energy=%g", sim.steps, energy)
            end
        end

        if save_ovf_every > 0
            if sim.steps%save_ovf_every == 0
                save_ovf(sim, @sprintf("%s_%d", sim.name, sim.steps), dataformat = ovf_format)
            end
        end

        if save_vtk_every > 0
            if sim.steps%save_vtk_every == 0
              save_vtk(sim, @sprintf("%s_%d", sim.name, sim.steps))
            end
        end

        if cubic
           run_step_cubic(sim)
        else
           run_step_triangular(sim)
        end

    end
end

function compute_clock_number(m::Array{T, 1}, cn::Array{Float32, 1},shape::Array{Bool},mesh::TriangularMeshGPU) where {T<:AbstractFloat}
    # nx,ny = mesh.nx, mesh.ny
    # v = zeros(T, nx*ny)
    # compute_skyrmion_number(v, m, mesh)
    # return sum(v)
  signA=zeros(typeof(0.0),6)
  ngbs = Array(mesh.ngbs)
  for i = 1:mesh.nxyz
    mx=m[i*3-2]
    my=m[i*3-1]
    if shape[i]
    if ngbs[1, i]==-1
     #     -m×n2+m×n3     -m×n5+m×n6
     signA.=( 0,-1, 1, 0,-1, 1)
     # cn[i]=1
    elseif ngbs[2, i]==-1
     # m×n1     -m×n3+m×n4     -m×n6
     signA.=( 1, 0,-1, 1, 0,-1)
     # cn[i]=2
    elseif ngbs[3, i]==-1
     #-m×n1+m×n2     -m×n4+m×n5
     signA.=(-1, 1, 0,-1, 1, 0)
     # cn[i]=3
    end
    for j=1:6
      id = ngbs[j, i]
      if id >0
        nx=m[id*3-2]
        ny=m[id*3-1]
        cn[i]+=signA[j]*(mx*ny-my*nx)
      end
    end
    cn[i]=cn[i]*2/sqrt(3)
    else
    cn[i]=NaN32
    end#if
  end

#     rij=zeros(Float32, 6,2)
#     rij[1,:].=(1,0)
#     rij[2,:].=( 0.5,0.5*sqrt(3))
#     rij[3,:].=(-0.5,0.5*sqrt(3))
#     rij[4,:].=(-1,0)
#     rij[5,:].=(-0.5,-0.5*sqrt(3))
#     rij[6,:].=( 0.5,-0.5*sqrt(3))
#     for i = 1:mesh.nxyz
#         mx=m[i*3-2]
#         my=m[i*3-1]
#         mz=m[i*3]
#         for j=1:6
#           id = ngbs[j, i]
#           if id >0
#             mnbx=m[id*3-2]
#             mnby=m[id*3-1]
#             mnbz=m[id*3]
# #rij[j,1](m_z mnb_x -m_x mnb_z)-rij[j,2](m_y mnb_z - m_z mnb_y) 
#             cn[i]+=rij[j,1]*(mz*mnbx-mx*mnbz)-rij[j,2]*(my*mnbz-mz*mnby)
#             # cn[i]+=1
#           end
#         end
#     end
end

function save_vtk_clocknum(sim::AbstractSimGPU,cn::Array{Float32, 1}, fname::String; fields::Array{String, 1} = String[])
  mesh = sim.mesh
  nx, ny, nz = mesh.nx, mesh.ny, mesh.nz
  xyz = zeros(Float32, 3, nx, ny, nz)
  dx, dy, dz=mesh.dx, mesh.dy, mesh.dz
  for k = 1:nz, j = 1:ny, i = 1:nx
    xyz[1, i, j, k] = (i-0.5)*dx - (j-1)*dx/2
    xyz[2, i, j, k] = (j-0.5)*dy
    xyz[3, i, j, k] = (k-0.5)*dz
  end

  vtk = vtk_grid(fname, xyz)
  T = _cuda_using_double.x ? Float64 : Float32
  spin = zeros(T, 3*sim.nxyz)
  copyto!(spin, sim.spin)
  b = reshape(spin, (3, nx, ny, nz))
  vtk_point_data(vtk, b , "m")
  vtk_point_data(vtk,reshape(cn,(nx, ny, nz)),"clocknum")
  if length(fields) > 0
    compute_fields_to_gpu(sim,sim.spin,0.0)
    fields = Set(fields)
    for i in sim.interactions
      if i.name in fields
        b = reshape(i.field, (3, nx, ny, nz))
        vtk_point_data(vtk, b, i.name)
      end
    end
  end
  vtk_save(vtk)
end