## Shootouts

type Shootout
  setups::Vector{Dict{Symbol,Any}}
  times#::Vector{Float64}
  errors#::Vector{uType}
  effs#::Vector{Float64} # Efficiencies
  effratios#::Matrix{uEltype}
  solutions
  names::Vector{String}
  N::Int
  bestidx::Int
  winner::String
end

type ShootoutSet
  shootouts::Vector{Shootout}
  probs#::Vector{DEProblem}
  probaux#::Vector{Dict{Symbol,Any}}
  N::Int
  winners::Vector{String}
end

function ode_shootout(prob::AbstractODEProblem,setups;appxsol=nothing,numruns=20,names=nothing,error_estimate=:final,kwargs...)
  N = length(setups)
  errors = Vector{Float64}(N)
  solutions = Vector{AbstractODESolution}(N)
  effs = Vector{Float64}(N)
  times = Vector{Float64}(N)
  effratios = Matrix{Float64}(N,N)
  timeseries_errors = error_estimate ∈ TIMESERIES_ERRORS
  dense_errors = error_estimate ∈ DENSE_ERRORS
  if names == nothing
    names = [string(typeof(setups[i][:alg])) for i=1:N]
  end
  for i in eachindex(setups)
    sol = solve(prob,setups[i][:alg];timeseries_errors=timeseries_errors,
    dense_errors = dense_errors,kwargs...,setups[i]...) # Compile and get result
    sol = solve(prob,setups[i][:alg],sol[:],sol.t,sol.k;timeseries_errors=timeseries_errors,
    dense_errors = dense_errors,kwargs...,setups[i]...) # Compile and get result
    t = @elapsed for j in 1:numruns
      sol = solve(prob,setups[i][:alg],sol[:],sol.t,sol.k;kwargs...,setups[i]...)
    end
    if appxsol != nothing
      errsol = appxtrue(sol,appxsol)
      errors[i] = errsol.errors[error_estimate]
      solutions[i] = errsol
    else
      errors[i] = sol.errors[error_estimate]
      solutions[i] = sol
    end
    effs[i] = 1/(errors[i]*t)
    t = t/numruns
    times[i] = t
  end
  for j in 1:N, i in 1:N
    effratios[i,j] = effs[i]/effs[j]
  end
  bestidx = find((y)->y==maximum(effs),effs)[1]; winner = names[bestidx]
  return Shootout(setups,times,errors,effs,effratios,solutions,names,N,bestidx,winner)
end

function ode_shootoutset{T<:AbstractODEProblem}(probs::Vector{T},setups;probaux=nothing,numruns=20,names=nothing,kwargs...)
  N = length(probs)
  shootouts = Vector{Shootout}(N)
  winners = Vector{String}(N)
  if names == nothing
    names = [string(typeof(setups[i][:alg])) for i=1:length(setups)]
  end
  if probaux == nothing
    probaux = Vector{Dict{Symbol,Any}}(N)
    for i in 1:N
      probaux[i] = Dict{Symbol,Any}()
    end
  end
  for i in eachindex(probs)
    shootouts[i] = ode_shootout(probs[i],setups;numruns=numruns,names=names,kwargs...,probaux[i]...)
    winners[i] = shootouts[i].winner
  end
  return ShootoutSet(shootouts,probs,probaux,N,winners)
end

length(shoot::Shootout) = shoot.N
Base.size(shoot::Shootout) = length(shoot)
Base.endof(shoot::Shootout) = length(shoot)
Base.getindex(shoot::Shootout,i::Int) = shoot.effs[i]
Base.getindex(shoot::Shootout,::Colon) = shoot.effs

function print(io::IO, shoot::Shootout)
  println(io,"Names: $(shoot.names), Winner: $(shoot.winner)")
  println(io,"Efficiencies: $(shoot.effs)")
  println(io,"EffRatios: $(shoot.effratios[shoot.bestidx,:])")
  println(io,"Times: $(shoot.times)")
  println(io,"Errors: $(shoot.errors)")
end

function show(io::IO, shoot::Shootout)
  println(io,"Winner: $(shoot.winner)")
  println(io,"EffRatios: $(shoot.effratios[shoot.bestidx,:])")
end

length(set::ShootoutSet) = set.N
Base.size(set::ShootoutSet) = length(set)
Base.endof(set::ShootoutSet) = length(set)
Base.getindex(set::ShootoutSet,i::Int) = set.shootouts[i]
Base.getindex(set::ShootoutSet,::Colon) = set.shootouts

function print(io::IO, set::ShootoutSet)
  println(io,"ShootoutSet of $(set.N) shootouts")
  println(io,"Winners: $(set.winners)")
end

function show(io::IO, set::ShootoutSet)
  println(io,"ShootoutSet of $(set.N) shootouts ")
end

## WorkPrecisions

type WorkPrecision
  prob
  abstols
  reltols
  errors
  times
  name
  N::Int
end

type WorkPrecisionSet
  wps::Vector{WorkPrecision}
  N::Int
  abstols
  reltols
  prob
  setups
  names
end

function ode_workprecision(prob::AbstractODEProblem,alg,abstols,reltols;name=nothing,numruns=20,appxsol=nothing,error_estimate=:final,kwargs...)
  N = length(abstols)
  errors = Vector{Float64}(N)
  times = Vector{Float64}(N)
  if name == nothing
    name = "WP-Alg"
  end
  timeseries_errors = error_estimate ∈ TIMESERIES_ERRORS
  dense_errors = error_estimate ∈ DENSE_ERRORS
  for i in 1:N
    sol = solve(prob,alg;kwargs...,abstol=abstols[i],
    reltol=reltols[i],timeseries_errors=timeseries_errors,
    dense_errors = dense_errors) # Compile and get result
    sol = solve(prob,alg,sol[:],sol.t,sol.k;kwargs...,abstol=abstols[i],
    reltol=reltols[i],timeseries_errors=timeseries_errors,
    dense_errors = dense_errors) # Compile and get result
    t = @elapsed for j in 1:numruns
      sol = solve(prob,alg,sol[:],sol.t,sol.k;kwargs...,abstol=abstols[i],
      reltol=reltols[i],timeseries_errors=timeseries_errors,
      dense_errors = dense_errors)
    end
    t = t/numruns

    if appxsol != nothing
      errsol = appxtrue(sol,appxsol)
      errors[i] = errsol.errors[error_estimate]
    else
      errors[i] = sol.errors[error_estimate]
    end
    times[i] = t
  end
  return WorkPrecision(prob,abstols,reltols,errors,times,name,N)
end

function ode_workprecision_set(prob::AbstractODEProblem,abstols,reltols,setups;numruns=20,names=nothing,appxsol=nothing,kwargs...)
  N = length(setups)
  wps = Vector{WorkPrecision}(N)
  if names == nothing
    names = [string(typeof(setups[i][:alg])) for i=1:length(setups)]
  end
  for i in 1:N
    wps[i] = ode_workprecision(prob,setups[i][:alg],abstols,reltols;numruns=numruns,appxsol=appxsol,name=names[i],kwargs...,setups[i]...)
  end
  return WorkPrecisionSet(wps,N,abstols,reltols,prob,setups,names)
end

length(wp::WorkPrecision) = wp.N
Base.size(wp::WorkPrecision) = length(wp)
Base.endof(wp::WorkPrecision) = length(wp)
Base.getindex(wp::WorkPrecision,i::Int) = wp.times[i]
Base.getindex(wp::WorkPrecision,::Colon) = wp.times

function print(io::IO, wp::WorkPrecision)
  println(io,"Name: $(wp.name)")
  println(io,"Times: $(wp.times)")
  println(io,"Errors: $(wp.errors)")
end

function show(io::IO, wp::WorkPrecision)
  println(io,"Name: $(wp.name)")
  println(io,"Times: $(wp.times)")
  println(io,"Errors: $(wp.errors)")
end

length(wp_set::WorkPrecisionSet) = wp_set.N
Base.size(wp_set::WorkPrecisionSet) = length(wp_set)
Base.endof(wp_set::WorkPrecisionSet) = length(wp_set)
Base.getindex(wp_set::WorkPrecisionSet,i::Int) = wp_set.wps[i]
Base.getindex(wp_set::WorkPrecisionSet,::Colon) = wp_set.wps

function print(io::IO, wp_set::WorkPrecisionSet)
  println(io,"WorkPrecisionSet of $(wp_set.N) wps")
  println(io,"Names: $(wp_set.names)")
end

function show(io::IO, wp_set::WorkPrecisionSet)
  println(io,"WorkPrecisionSet of $(wp_set.N) wps")
end
