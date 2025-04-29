using Distributions, Random, Serialization, StatsBase
import CSV

@isdefined(FactorGraph)      || include(string(@__DIR__, "/fg/factor_graph.jl"))
@isdefined(color_passing)    || include(string(@__DIR__, "/fg/color_passing.jl"))
@isdefined(colors_to_groups) || include(string(@__DIR__, "/fg/fg_to_pfg.jl"))

"""
	load_from_file(path::String)

Load a serialized object from the given file.
"""
function load_from_file(path::String)
	io = open(path, "r")
	obj = deserialize(io)
	close(io)
	return obj
end

"""
	save_to_file(obj, path::String)

Serialize an object to a given file.
"""
function save_to_file(obj, path::String)
	open(path, "w") do io
		serialize(io, obj)
	end
end

"""
	load_df(file::AbstractString)::DataFrame

Load a `.csv` file into a DataFrame.
"""
function load_df(file::AbstractString)::DataFrame
	return CSV.File(file) |> DataFrame
end

"""
	execute_inference_algo(
		jar_file::String,
		input_file::String,
		engine::String,
		output_dir=string(@__DIR__, "/../results/"),
	)::Dict{String, Float64}

Execute the `.jar` file with the specified inference engine on the specified
BLOG input file.
"""
function execute_inference_algo(
	jar_file::String,
	input_file::String,
	engine::String,
	output_dir=string(@__DIR__, "/../results/"),
)::Dict{String, Float64}
	@assert engine in [
		"jt.JTEngine",
		"fojt.LiftedJTEngine",
		"ve.VarElimEngine",
		"fove.LiftedVarElim"
	]
	cmd = `java -jar $jar_file -e $engine -o $output_dir $input_file`
	res = run_with_timeout(cmd)
	return res == "timeout" ? Dict("timeout" => 1) : parse_blog_output(res)
end

"""
	run_with_timeout(command, timeout::Int = 300)

Run an external command with a timeout. If the command does not finish within
the specified timeout, the process is killed and `timeout` is returned.
"""
function run_with_timeout(command, timeout::Int = 300)
	out = Pipe()
	cmd = run(pipeline(command, stdout=out); wait=false)
	close(out.in)
	for _ in 1:timeout
		!process_running(cmd) && return read(out, String)
		sleep(1)
	end
	kill(cmd)
	return "timeout"
end

"""
	dist_to_str(d::Dict{String, Float64})::String

Convert a distribution for a random variable to a string that can be shown
in the logfile.
"""
function dist_to_str(d::Dict{String, Float64})::String
	haskey(d, "timeout") && return "timeout"
	return join(["$k=$v" for (k, v) in d], ";")
end

"""
	dist_to_fn(d::Dict{String, Float64})::Function

Convert a distribution for a Boolean random variable to a function
(for the purpose of computing the KL divergence).
"""
function dist_to_fn(d::Dict{String, Float64})::Function
	# Note that this works only for Boolean random variables
	eps = 1e-14 # Avoid division by zero in KL divergence
	if !haskey(d, "true") && haskey(d, "false")
		d["true"] = 1.0 - d["false"]
	elseif !haskey(d, "false") && haskey(d, "true")
		d["false"] = 1.0 - d["true"]
	end
	if d["false"] == 0.0
		d["false"] = eps
		d["true"] = 1.0 - eps
	elseif d["true"] == 0.0
		d["true"] = eps
		d["false"] = 1.0 - eps
	end
	return function(x)
		return x == 0 ? d["false"] : d["true"]
	end
end

"""
	kl_divergence(p::Function, q::Function)::Float64

Compute the Kullback-Leibler divergence between two probability distributions
`p` and `q` over the given domain `d`.
"""
function kl_divergence(p::Function, q::Function, d::Vector)::Float64
	return sum([p(x) * log(p(x) / q(x)) for x in d])
end

"""
	chan_distance(p::Function, q::Function, d::Vector)::Float64

Compute the distance measure introduced in the paper
"A Distance Measure for Bounding Probabilistic Belief Change"
by Hei Chan and Adnan Darwiche between two probability distributions
`p` and `q` over the given domain `d`.

### References
Hei Chan and Adnan Darwiche.
A Distance Measure for Bounding Probabilistic Belief Change.
International Journal of Approximate Reasoning, 38:149-174, 2005.
"""
function chan_distance(p::Function, q::Function, d::Vector)::Float64
	quotients = [p(x) > 0 ? q(x) / p(x) : 1 for x in d]
	return log(maximum(quotients)) - log(minimum(quotients))
end

"""
	parse_blog_output(o::AbstractString)::Dict{String, Float64}

Retrieve the probability distribution from the output of the BLOG inference
algorithm.
"""
function parse_blog_output(o::AbstractString)::Dict{String, Float64}
	dist = Dict{String, Float64}()
	flag = false
	for line in split(o, "\n")
		if flag && !isempty(strip(line))
			prob, val = split(replace(lstrip(line), r"\s" => " "), " ")
			dist[val] = parse(Float64, prob)
		end
		occursin("Distribution of values for", line) && (flag = true)
		occursin("mem error", line) && return Dict("timeout" => 1)
	end
	return dist
end

"""
	is_equal_epsilon(val1::Number, val2::Number, epsilon::Float64)::Bool

Check if two numbers are equal with an allowed difference controlled by the
parameter `epsilon`.
This implementation checks whether `val2` lies in the interval
[`val1` - `val1` * `epsilon`, `val1` + `val1` * `epsilon`] and
`val1` lies within the interval
[`val2` - `val2` * `epsilon`, `val2` + `val2` * `epsilon`].
"""
function is_equal_epsilon(val1::Number, val2::Number, epsilon::Float64)::Bool
	@assert epsilon >= 0.0
	@assert epsilon <= 1.0

	return val2 >= val1 - val1 * epsilon && val2 <= val1 + val1 * epsilon &&
		val1 >= val2 - val2 * epsilon && val1 <= val2 + val2 * epsilon
end

"""
	permute_factors!(fg::FactorGraph, p::AbstractFloat, seed::Int=123)::Int

Permute the factors in a factor graph `fg` with probability `p` (i.e., change
the order of their arguments without changing their semantics).
Return the number of factors that have been permuted.
"""
function permute_factors!(fg::FactorGraph, p::AbstractFloat, seed::Int=123)::Int
	Random.seed!(seed)
	num_perm = 0
	for f in factors(fg)
		length(rvs(f)) > 1 || continue
		if rand() < p
			permute_factor!(f, seed + num_perm)
			num_perm += 1
		end
	end
	return num_perm
end

"""
	permute_factor!(f::Factor, seed::Int=123)

Permute the arguments of the given factor `f` (without changing its semantics).
"""
function permute_factor!(f::Factor, seed::Int=123)
	Random.seed!(seed)

	permutation = shuffle(1:length(rvs(f)))
	new_potentials = Dict()
	for c in collect(Base.Iterators.product(map(x -> range(x), f.rvs)...))
		new_c = collect(c)
		new_c = [new_c[i] for i in permutation]
		new_potentials[join(new_c, ",")] = potential(f, collect(c))
	end
	f.potentials = new_potentials
	f.rvs = [f.rvs[i] for i in permutation]
end

"""
	gen_randpots(ds::Array, seed::Int=123)::Vector{Tuple{Vector, Float64}}

Generate random potentials for a given array of ranges.
"""
function gen_randpots(rs::Array, seed::Int=123)::Vector{Tuple{Vector, Float64}}
	Random.seed!(seed)
	length(rs) > 5 && @warn("Generating at least $(2^length(rs)) potentials!")

	potentials = []
	for conf in Iterators.product(rs...)
		push!(potentials, ([conf...], rand(0.1:0.1:2.0)))
	end

	return potentials
end

"""
	gen_asc_pots(ds::Array)::Vector{Tuple{Vector, Float64}}

Generate ascending potentials for a given array of ranges (especially useful
for debugging purposes).
"""
function gen_asc_pots(rs::Array)::Vector{Tuple{Vector, Float64}}
	length(rs) > 5 && @warn("Generating at least $(2^length(rs)) potentials!")

	potentials = []
	i = 1
	for conf in Iterators.product(rs...)
		push!(potentials, ([conf...], i))
		i += 1
	end

	return potentials
end

"""
	gen_same_pots(rs::Array, val::Int=1)::Vector{Tuple{Vector, Float64}}

Generate identical potentials for all assignments for a given array of ranges.
"""
function gen_same_pots(rs::Array, val::Int=1)::Vector{Tuple{Vector, Float64}}
	length(rs) > 5 && @warn("Generating at least $(2^length(rs)) potentials!")

	potentials = []
	for conf in Iterators.product(rs...)
		push!(potentials, ([conf...], val))
	end

	return potentials
end


"""
	gen_commutative_randpots(rs::Array, comm_indices::Vector{Int}, seed::Int=123)::Vector{Tuple{Vector, Float64}}

Generate random commutative potentials for a given array of ranges.
The second parameter `comm_indices` specifies the indices of the ranges
that should be commutative.
"""
function gen_commutative_randpots(
	rs::Array,
	comm_indices::Vector{Int},
	seed::Int=123
)::Vector{Tuple{Vector, Float64}}
	@assert !isempty(comm_indices)
	@assert all(idx -> 1 <= idx <= length(rs), comm_indices)
	@assert all(idx -> rs[idx] == rs[comm_indices[1]], comm_indices)

	Random.seed!(seed)
	length(rs) > 5 && @warn("Generating at least $(2^length(rs)) potentials!")

	com_range = rs[comm_indices[1]]
	vals = Dict()
	potentials = []
	for conf in Iterators.product(rs...)
		key_parts = Vector{Int}(undef, length(com_range))
		for (idx, range_val) in enumerate(com_range)
			com_vals = [val for (idx, val) in enumerate(conf) if idx in comm_indices]
			key_parts[idx] = count(x -> x == range_val, com_vals)
		end
		key = join(key_parts, "-")
		!haskey(vals, key) && (vals[key] = rand(0.1:0.1:2.0))
		push!(potentials, ([conf...], vals[key]))
	end

	return potentials
end

"""
	add_noise!(potentials::Dict, epsilon::Float64, seed::Int=123)

Add noise to the given potentials.
"""
function add_noise!(potentials::Dict, epsilon::Float64, seed::Int=123)
	Random.seed!(seed)
	sign = rand([-1,1])
	for (key, _) in potentials
		sign *= -1
		sign == -1 && (epsilon = epsilon / (1 + epsilon))
		potentials[key] += potentials[key] * sign * rand(Uniform(0, epsilon))
	end
end

"""
	nanos_to_millis(t::AbstractFloat)::Float64

Convert nanoseconds to milliseconds.
"""
function nanos_to_millis(t::AbstractFloat)::Float64
    # Nano /1000 -> Micro /1000 -> Milli /1000 -> Second
    return t / 1000 / 1000
end