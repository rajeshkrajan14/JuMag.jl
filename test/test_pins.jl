using JuMag
using Test
using NPZ

function init_mm(i,j,k,dx,dy,dz)
    if i == 1
        return (0,0,1)
    elseif  i == 100
        return (0,1,0)
    else
        return (1,1,1)
    end
end

function pinning_boundary(i,j,k,dx,dy,dz)
    if i == 1 || i == 100
        return true
    end
    return false
end

function relax_system(mesh; driver="LLG")
	sim = Sim(mesh, name="test_pinning", driver=driver)
    if driver == "LLG"
        sim.driver.precession = false
        sim.driver.alpha = 0.5
    end
    set_Ms(sim, 8.6e5)
    set_pinning(sim, pinning_boundary)

    add_exch(sim, 1.3e-11)
    #add_anis(sim, 1e5, axis=(1,0,0))

    init_m0(sim, init_mm)
    relax(sim, maxsteps=10000, stopping_dmdt=0.1, save_vtk_every = -1)
    save_vtk(sim, "pinning.vts")
    m = Array(sim.spin)

    @test abs(m[1])<1e-15
    @test abs(m[2])<1e-15
    @test abs(m[3]-1)<1e-15

    #@test abs(m[2])<0.04
    #@test abs(m[3])<0.01
end


@testset "TestPinning" begin
    mesh =  FDMesh(nx=100, ny=1, nz=1, dx=2e-9, dy=2e-9, dz=1e-9)
    relax_system(mesh, driver="LLG")
    relax_system(mesh, driver="SD")
end

if JuMag._cuda_available.x
  JuMag.cuda_using_double()
  @testset "TestPinning GPU" begin
      mesh =  FDMeshGPU(nx=100, ny=1, nz=1, dx=2e-9, dy=2e-9, dz=1e-9)
      relax_system(mesh, driver="LLG")
      relax_system(mesh, driver="SD")
  end
end
