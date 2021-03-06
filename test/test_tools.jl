using JuMag
using Test
using Printf

function minor_test_pj()
	nx,ny,nz = 2,2,1
	Nx,Ny = 4,4
	m = [-1,0,0, 1,0,0, 0,1,0, 0,-1,0.0]
	b = reshape(m,(3,nx,ny,nz))
	mx,my,mz = b[1,:,:,:],b[2,:,:,:],b[3,:,:,:]

	smx,smy,smz = JuMag.Make_Projection(mx,my,mz,Nx=4,Ny=4)
	@test smx[2,2] == -1
	@test smx[2,3] == 0
	@test smx[3,2] == 1
	@test smx[3,3] == 0
	@test smy[2,2] == 0
	@test smy[2,3] == 1
	@test smy[3,2] == 0
	@test smy[3,3] == -1
end

function mini_test()
	mesh = FDMesh(nx=2,ny=1,nz=1)
	sim = Sim(mesh)
	set_Ms(sim,1e4)
	init_m0(sim,(0,0,1))
	m = sim.spin
	smx,smy,smz = JuMag.Make_Projection(m,2,1,1,Nx=2,Ny=1,beta=pi/3,gamma=0,ItpNum=0)
	@test(abs(smx[1,1]+sqrt(3)/2)<1e-4)
	@test(abs(smx[2,1]+sqrt(3)/2)<1e-4)
	@test(abs(smz[1,1]-1/2)<1e-4)
	@test(abs(smz[2,1]-1/2)<1e-4)
end

function test_tilt_beta()
	mesh = FDMesh(nx=128,ny=128,nz=1)
	sim = Sim(mesh)
	set_Ms(sim,1e4)
	init_m0(sim,(0,0,1))
	m = sim.spin
	smx,smy,smz = JuMag.Make_Projection(m,128,128,1,Nx=128,Ny=128,beta=pi/3,gamma=0,ItpNum=0)
	@test(abs(smx[64,64]+sqrt(3)/2*2)<1e-4)
	@test(abs(smz[64,64]-1/2*2)<1e-4)
	@test(abs(sum(smx)+sqrt(3)/2*128*128)<1e-2)
end

function test_tilt_gamma()
	mesh = FDMesh(nx=16,ny=16,nz=1)
	sim = Sim(mesh)
	set_Ms(sim,1e4)
	init_m0(sim,(0,0,1))
	m = sim.spin
	smx,smy,smz = JuMag.Make_Projection(m,16,16,1,Nx=128,Ny=128,beta=0,gamma=pi/3,ItpNum=0)
	@test(abs(smy[64,64]+sqrt(3)/2*2)<1e-4)
	@test(abs(smz[64,64]-1/2*2)<1e-4)
	@test(abs(sum(smy)+sqrt(3)/2*128*128)<1e-2)
end
function test_tiltbeta_multilayer()
	mesh = FDMesh(nx=64,ny=64,nz=64)
	sim = Sim(mesh)
	set_Ms(sim,1e4)
	init_m0(sim,(0,0,1))
	m = sim.spin
	smx,smy,smz = JuMag.Make_Projection(m,64,64,64,Nx=128,Ny=128,beta=pi/4,gamma=0,ItpNum=0)
	@test(abs( (32*sqrt(2)-0.5)/(32*sqrt(2)*64+smx[64,64]) )<1e-1)
	@test(abs( (32*sqrt(2)-0.5)/(32*sqrt(2)*64-smz[64,64]) )<1e-1)
	@test(sum(smx)+64*64*64*sqrt(2)/2<1)
end
function test_tiltgamma_multilayer()
	mesh = FDMesh(nx=64,ny=64,nz=64)
	sim = Sim(mesh)
	set_Ms(sim,1e4)
	init_m0(sim,(0,0,1))
	m = sim.spin
	smx,smy,smz = JuMag.Make_Projection(m,64,64,64,Nx=128,Ny=128,gamma=pi/4,ItpNum=0)
	@test(abs( (32*sqrt(2)-0.5)/(32*sqrt(2)*64+smy[64,64]) )<1e-1)
	@test(abs( (32*sqrt(2)-0.5)/(32*sqrt(2)*64-smz[64,64]) )<1e-1)
	@test(sum(smy)+64*64*64*sqrt(2)/2<1)
end

mini_test()
test_tilt_beta()
test_tiltbeta_multilayer()
test_tiltgamma_multilayer()
@info("Test Make_Projection Passed!")