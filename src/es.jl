# Evolution Strategy
# ==================
#
# Implementation: (μ/ρ(+/,)λ)-ES
#
# μ is the number of parents
# ρ ≤ μ the mixing number (i.e., the number of parents involved in the procreation of an offspring)
# λ is the number of offspring.
#
# Comma-selection (μ<λ must hold): parents are deterministically selected from the set of the offspring
# Plus-selection: parents are deterministically selected from the set of both the parents and offspring
#
# Parameters:
# - objfun: the optimized objective function
# - population: the population array of individuals of type `T`
#
function es(  objfun::Function, population::Vector{T};
              initStrategy::Strategy = strategy(),
              recombination::Function = (rs->rs[1]),
              srecombination::Function = (ss->ss[1]),
              mutation::Function = ((r,m)->r),
              smutation::Function = (s->s),
              termination::Function = (x->false),
              μ::Integer = 1,
              ρ::Integer = μ,
              λ::Integer = 1,
              selection::Symbol = :plus,
              iterations::Integer = length(population)*100,
              verbose = false, debug = false,
              interim = false) where {T}

    @assert ρ <= μ "Number of parents involved in the procreation of an offspring should be no more then total number of parents"
    if selection == :comma
        @assert μ < λ "Offspring population must be larger then parent population"
    end

    store = Dict{Symbol,Any}()

    # Initialize parent population
    @assert length(population) >= μ "Population size cannot be less then μ=$μ"
    resize!(population, μ)
    fitness = zeros(μ)
    offspring = Array{T}(undef, λ)
    fitoff = fill(Inf, λ)
    stgpop = fill(initStrategy, μ)
    stgoff = fill(initStrategy, λ)

    keep(interim, :fitness, copy(fitness), store)

    # Generation cycle
    count = 0
    while true

        for i in 1:λ
            # Recombine the ρ selected parents to form a recombinant individual
            if ρ == 1
                j = rand(1:μ)
                recombinantStrategy = stgpop[j]
                recombinant = copy(population[j])
            else
                idx = randperm(μ)[1:ρ]
                recombinantStrategy = srecombination(stgpop[idx])
                recombinant = recombination(population[idx])
            end

            # Mutate the strategy parameter set of the recombinant
            stgoff[i] = smutation(recombinantStrategy)

            # Mutate the objective parameter set of the recombinant using the mutated strategy parameter set
            # to control the statistical properties of the object parameter mutation
            offspring[i] = mutation(recombinant, stgoff[i])

            # Evaluate fitness
            fitoff[i] = objfun(offspring[i])
        end

        # Select new parent population
        if selection == :plus
            idx = sortperm(vcat(fitness, fitoff))[1:μ]
            skip = idx[idx.<=μ]
            for i = 1:μ
                if idx[i] ∉ skip
                    ii = idx[i] - μ
                    population[i] = offspring[ii]
                    stgpop[i] = stgoff[ii]
                    fitness[i] = fitoff[ii]
                end
            end
        else
            idx = sortperm(fitoff)[1:μ]
            population = offspring[idx]
            stgpop = stgoff[idx]
            fitness = fitoff[idx]
        end
        keep(interim, :fitness, copy(fitness), store)
        keep(interim, :fitoff, copy(fitoff), store)

        # termination condition
        count += 1
        if count == iterations || termination(stgpop[1])
            break
        end
        verbose && println("BEST: $(fitness[1]): $(stgpop[1])")
    end

    return population[1], fitness[1], count, store
end

# Spawn population from one individual
function es(objfun::Function, individual::Vector{T}; μ::Integer=1, kwargs...) where {T<:Real}
    N = length(individual)
    population = [individual .* rand(T, N) for i in 1:μ]
    return es(objfun, population; μ=μ, kwargs...)
end

# Spawn population from matrix of individuals
function es(objfun::Function, population::Matrix{T}; kwargs...) where {T<:Real}
    μ = size(population, 2)
    return es(objfun, [population[:,i] for i in axes(population, 2)]; μ=μ, kwargs...)
end

# Spawn population using creation function and individual size
function es(objfun::Function, N::Int; creation=(n)->rand(n), μ::Integer=1, kwargs...)
    return es(objfun, [creation(N) for i in 1:μ]; μ=μ, kwargs...)
end

