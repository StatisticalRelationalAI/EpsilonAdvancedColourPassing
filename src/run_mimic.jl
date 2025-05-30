using BenchmarkTools, DataFrames, Dates, Random, Statistics

@isdefined(DataBase)                || include(string(@__DIR__, "/database/database.jl"))
@isdefined(dataframe_to_num!)       || include(string(@__DIR__, "/database/dataframes.jl"))
@isdefined(learn_pfg!)              || include(string(@__DIR__, "/database/learning.jl"))
@isdefined(load_from_file)          || include(string(@__DIR__, "/helper.jl"))
@isdefined(FactorGraph)             || include(string(@__DIR__, "/fg/factor_graph.jl"))
@isdefined(ParfactorGraph)          || include(string(@__DIR__, "/pfg/parfactor_graph.jl"))
@isdefined(advanced_color_passing!) || include(string(@__DIR__, "/fg/advanced_color_passing.jl"))
@isdefined(groups_to_pfg)           || include(string(@__DIR__, "/fg/fg_to_pfg.jl"))
@isdefined(model_to_blog)           || include(string(@__DIR__, "/pfg/blog_parser.jl"))
@isdefined(blog_to_queries)         || include(string(@__DIR__, "/queries.jl"))

function run_eval(
	input_dir=string(@__DIR__, "/../instances/mimic/"),
	output_dir=string(@__DIR__, "/../instances/output/"),
	logfile=string(@__DIR__, "/../results/results-mimic.csv"),
	jar_file=string(@__DIR__, "/../instances/ljt-v1.0-jar-with-dependencies.jar"),
	seed=123
)
	Random.seed!(seed)
	logfile_exists = isfile(logfile)

	csv_cols = string(
		"instance,", # name of the input instance
		"radius,", # radius of DBSCAN
		"algo,", # name of the colour passing variant (ACP or EACP)
		"epsilon,", # value of parameter epsilon
		"query,", # name of the query
		"n_rvs,", # number of random variables
		"n_factors,", # number of factors
		"n_max_args,", # max number of arguments of a factor
		"n_rvs_compressed,", # number of random variables after compression
		"n_factors_compressed,", # number of factors after compression
		"perc_reduced_size,", # percentage of reduction in size (size = n_rvs + n_factors)
		"largest_group_size,", # size of the largest group
		"num_groups,", # number of groups
		"cp_runtime,", # runtime of offline compression
		"kl_divergence,", # KL divergence between choice of epsilon and epsilon = 0
		"chan_dist,", # Chan distance between choice of epsilon and epsilon = 0
		"query_quotient,", # Quotient of the query results from ACP and EACP
		"query_result", # result of the query
		"\n"
	)

	open(logfile, "a") do io
		!logfile_exists && write(io, csv_cols)

		for (root, dirs, files) in walkdir(input_dir)
			for f in files
				endswith(f, ".ser") || continue
				fpath = string(root, endswith(root, "/") ? "" : "/", f)
				@info "Processing file '$fpath'..."
				fg, queries = load_from_file(fpath)
				n_rvs = numrvs(fg)
				n_factors = numfactors(fg)
				n_max_args = maximum([length(rvs(f)) for f in factors(fg)])
				radius = match(r"eps=(\d+)-", fpath)[1]
				radius = parse(Float64, string(radius[1], ".", radius[2:end]))

				# IMPORTANT: ACP changes the order of arguments in factors.
				# Thus, run ACP on a copy of the input!
				dist_grt = Dict{Query, Dict{String, Float64}}()
				for epsilon in [0.0, 0.1]
					cp_name = epsilon == 0.0 ? "ACP" : "EACP"
					fg_cpy_bench = deepcopy(fg)
					fg_cpy_res = deepcopy(fg)
					algo = advanced_color_passing!
					@info "Running ACP with epsilon = $epsilon..."
					bench = @benchmark $algo($fg_cpy_bench, $Dict{Factor, Int}(), $epsilon) samples=1 evals=1
					node_c, factor_c, com_args_cache, hist_cache = algo(fg_cpy_res, Dict{Factor, Int}(), epsilon)

					n_rvs_compressed = length(unique(values(node_c)))
					n_factors_compressed = length(unique(values(factor_c)))
					perc_reduced_size = (n_rvs_compressed + n_factors_compressed) /
						(n_rvs + n_factors)

					@info "Converting output of ACP to blog file..."

					pfg, rv_to_ind = groups_to_pfg(
						fg_cpy_res,
						node_c,
						factor_c,
						com_args_cache,
						hist_cache
					)
					largest_group_size = maximum(
						[isempty(logvars(prv)) ? 1 :
							reduce(+, map(lv -> length(domain(lv)), logvars(prv)))
						for prv in prvs(pfg)]
					)
					num_groups = length(prvs(pfg))
					io_buffer = IOBuffer()
					model_to_blog(pfg, io_buffer)
					model_str = String(take!(io_buffer))
					for (idx, query) in enumerate(queries)
						new_f = string(
							output_dir,
							replace(f, ".ser" => "-cp=$cp_name-q$idx.blog")
						)
						open(new_f, "w") do out_io
							write(out_io, model_str)
							write(out_io, join(query_to_blog(query, rv_to_ind), "\n"))
						end

						@info "\t'LVE' for query $query..."
						dist = execute_inference_algo(
							jar_file,
							new_f,
							"fove.LiftedVarElim",
							replace(logfile, ".csv" => "")
						)
						epsilon == 0.0 && (dist_grt[query] = dist)
						if !haskey(dist_grt[query], "timeout") && !haskey(dist, "timeout")
							dist_grt_as_fn = dist_to_fn(dist_grt[query])
							dist_as_fn = dist_to_fn(dist)
							kl_div = kl_divergence(
								dist_grt_as_fn,
								dist_as_fn,
								[0, 1],
							)
							# Due to floating point arithmetic the distribution
							# might not exactly sum up to 1 and kl_div becomes
							# negative.
							kl_div < 0 && (kl_div = kl_divergence(
								dist_as_fn,
								dist_grt_as_fn,
								[0, 1],
							))
							chan_dist = chan_distance(
								dist_grt_as_fn,
								dist_as_fn,
								[0, 1],
							)
							query_quotient = "true=$(dist_as_fn(1) / dist_grt_as_fn(1));false=$(dist_as_fn(0) / dist_grt_as_fn(0))"
						else
							kl_div = "timeout"
							chan_dist = "timeout"
							query_quotient = "timeout"
						end

						write(io, join([
							replace(f, ".ser" => "-cp=$cp_name-q$idx"),
							radius,
							cp_name,
							epsilon,
							query,
							n_rvs,
							n_factors,
							n_max_args,
							n_rvs_compressed,
							n_factors_compressed,
							perc_reduced_size,
							largest_group_size,
							num_groups,
							nanos_to_millis(mean(bench.times)),
							kl_div,
							chan_dist,
							query_quotient,
							dist_to_str(dist)
						], ","), "\n")
						flush(io)
					end
				end
			end
		end
	end
end


### Entry point ###
if abspath(PROGRAM_FILE) == @__FILE__
	"debug" in ARGS && (ENV["JULIA_DEBUG"] = "all")
	start = Dates.now()

	run_eval()

	@info "=> Start:      $start"
	@info "=> End:        $(Dates.now())"
	@info "=> Total time: $(Dates.now() - start)"
end