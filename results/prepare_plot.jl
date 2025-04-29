using Statistics

@isdefined(nanos_to_millis) || include(string(@__DIR__, "/../src/helper.jl"))

"""
	prepare_query_times_main(file::String)

Build averages over multiple runs and write the results into a new `.csv` file
that is used for plotting in the main paper.
"""
function prepare_query_times_main(file::String)
	if !isfile(file)
		@warn "File '$file' does not exist and is ignored."
		return
	end

	new_file = replace(file, ".csv" => "-prepared-main.csv")
	if isfile(new_file)
		@warn "File '$new_file' already exists and is ignored."
		return
	end

	averages = Dict()
	open(file, "r") do io
		readline(io) # Remove header
		for line in readlines(io)
			cols = split(line, ",")
			algo = match(r"-cp=([a-zA-Z]+)-", cols[2])[1]
			d = parse(Int, match(r"-d1?=(\d+)-", cols[2])[1])
			time = nanos_to_millis(parse(Float64, cols[12]))
			haskey(averages, algo) || (averages[algo] = Dict())
			haskey(averages[algo], d) || (averages[algo][d] = [])
			push!(averages[algo][d], time)
		end
	end

	open(new_file, "a") do io
		write(io, "d,algo,min_t,max_t,mean_t,median_t,std\n")
		for (algo, ds) in averages
			for (d, times) in ds
				# Average with timeouts does not work
				if any(t -> isnan(t), times)
					@warn "Ignoring $algo with d=$d due to NaN values."
					continue
				end
				write(io, string(
					d, ",",
					algo, ",",
					minimum(times), ",",
					maximum(times), ",",
					mean(times), ",",
					median(times), ",",
					std(times), "\n"
				))
			end
		end
	end
end

"""
	prepare_kl_main(file::String)

Parse the Kullback-Leibler divergences for the main paper and
write the results into a new `.csv` file.
"""
function prepare_kl_main(file::String)
	if !isfile(file)
		@warn "File '$file' does not exist and is ignored."
		return
	end

	new_file = replace(file, ".csv" => "-prepared-main.csv")
	if isfile(new_file)
		@warn "File '$new_file' already exists and is ignored."
		return
	end

	averages = Dict()
	open(file, "r") do io
		readline(io) # Remove header
		for line in readlines(io)
			cols = split(line, ",")
			algo = cols[2]
			algo == "EACP" || continue
			d = parse(Int, cols[4])
			kl_divergence = parse(Float64, cols[16])
			isnan(kl_divergence) && continue
			kl_divergence < 0 && @warn "Negative KL divergence for $(cols[1])"
			haskey(averages, d) || (averages[d] = [])
			push!(averages[d], kl_divergence)
		end
	end
	open(new_file, "a") do io
		write(io, "d,min_kl_div,max_kl_div,mean_kl_div,median_kl_div,std\n")
		for (d, divs) in averages
			s = string(
				d, ",",
				minimum(divs), ",",
				maximum(divs), ",",
				mean(divs), ",",
				median(divs), ",",
				std(divs), "\n"
			)
			write(io, s)
		end
	end
end

"""
	prepare_quotient_main(file::String)

Build quotients of new and old query results and write the results into a new
`.csv` file.
"""
function prepare_quotient_main(file::String)
	if !isfile(file)
		@warn "File '$file' does not exist and is ignored."
		return
	end

	new_file = replace(file, ".csv" => "-prepared-main.csv")
	if isfile(new_file)
		@warn "File '$new_file' already exists and is ignored."
		return
	end

	averages = Dict()
	open(file, "r") do io
		readline(io) # Remove header
		for line in readlines(io)
			cols = split(line, ",")
			algo = cols[2]
			algo == "EACP" || continue
			eps = parse(Float64, cols[3])
			d = parse(Int, cols[4])
			p = parse(Float64, cols[5])
			quotient = match(r"true=(\d\.\d+);false=(\d\.\d+)", cols[18])
			# Nothing for "timeout" and "true=NaN;false=NaN"
			isnothing(quotient) && continue
			q1, q2 = parse(Float64, quotient[1]), parse(Float64, quotient[2])
			haskey(averages, d) || (averages[d] = Dict())
			haskey(averages[d], eps) || (averages[d][eps] = Dict())
			haskey(averages[d][eps], p) || (averages[d][eps][p] = [])
			push!(averages[d][eps][p], q1)
			push!(averages[d][eps][p], q2)
		end
	end

	open(new_file, "a") do io
		write(io, "d,eps,p,quotient\n")
		for (d, epss) in averages
			for (eps, ps) in epss
				for (p, qs) in ps
					for q in qs
						write(io, string(
							d, ",",
							eps, ",",
							p, ",",
							q, "\n"
						))
					end
				end
			end
		end
	end
end

"""
	prepare_query_times_appendix(file::String)

Build averages over multiple runs and write the results into a new `.csv` file
that is used for plotting in the appendix.
"""
function prepare_query_times_appendix(file::String)
	if !isfile(file)
		@warn "File '$file' does not exist and is ignored."
		return
	end

	new_file = replace(file, ".csv" => "-prepared-appendix.csv")
	if isfile(new_file)
		@warn "File '$new_file' already exists and is ignored."
		return
	end

	averages = Dict()
	open(file, "r") do io
		readline(io) # Remove header
		for line in readlines(io)
			cols = split(line, ",")
			algo = match(r"-cp=([a-zA-Z]+)-", cols[2])[1]
			d = parse(Int, match(r"-d1?=(\d+)-", cols[2])[1])
			p = match(r"-p=(\d+)-", cols[2])[1]
			p = parse(Float64, string(p[1], ".", p[2:end]))
			eps = match(r"-eps=(\d+)-", cols[2])[1]
			eps = parse(Float64, string(eps[1], ".", eps[2:end]))
			time = nanos_to_millis(parse(Float64, cols[12]))
			haskey(averages, algo) || (averages[algo] = Dict())
			haskey(averages[algo], d) || (averages[algo][d] = Dict())
			haskey(averages[algo][d], eps) || (averages[algo][d][eps] = Dict())
			haskey(averages[algo][d][eps], p) || (averages[algo][d][eps][p] = [])
			push!(averages[algo][d][eps][p], time)
		end
	end

	open(new_file, "a") do io
		write(io, "d,epsilon,p,algo,min_t,max_t,mean_t,median_t,std\n")
		for (algo, ds) in averages
			for (d, epss) in ds
				for (eps, ps) in epss
					for (p, times) in ps
						# Average with timeouts does not work
						if any(t -> isnan(t), times)
							@warn "Ignoring $algo with d=$d due to NaN values."
							continue
						end
						write(io, string(
							d, ",",
							eps, ",",
							p, ",",
							algo, ",",
							minimum(times), ",",
							maximum(times), ",",
							mean(times), ",",
							median(times), ",",
							std(times), "\n"
						))
					end
				end
			end
		end
	end
end

"""
	prepare_kl_appendix(file::String)

Parse the Kullback-Leibler divergences for the appendix and
write the results into a new `.csv` file.
"""
function prepare_kl_appendix(file::String)
	if !isfile(file)
		@warn "File '$file' does not exist and is ignored."
		return
	end

	new_file = replace(file, ".csv" => "-prepared-appendix.csv")
	if isfile(new_file)
		@warn "File '$new_file' already exists and is ignored."
		return
	end

	averages = Dict()
	open(file, "r") do io
		readline(io) # Remove header
		for line in readlines(io)
			cols = split(line, ",")
			algo = cols[2]
			algo == "EACP" || continue
			eps = parse(Float64, cols[3])
			d = parse(Int, cols[4])
			p = parse(Float64, cols[5])
			kl_divergence = parse(Float64, cols[16])
			isnan(kl_divergence) && continue
			kl_divergence < 0 && @warn "Negative KL divergence for $(cols[1])"
			haskey(averages, d) || (averages[d] = Dict())
			haskey(averages[d], eps) || (averages[d][eps] = Dict())
			haskey(averages[d][eps], p) || (averages[d][eps][p] = [])
			push!(averages[d][eps][p], kl_divergence)
		end
	end
	open(new_file, "a") do io
		write(io, "d,eps,p,min_kl_div,max_kl_div,mean_kl_div,median_kl_div,std\n")
		for (d, epss) in averages
			for (eps, ps) in epss
				for (p, divs) in ps
					s = string(
						d, ",",
						eps, ",",
						p, ",",
						minimum(divs), ",",
						maximum(divs), ",",
						mean(divs), ",",
						median(divs), ",",
						std(divs), "\n"
					)
					write(io, s)
				end
			end
		end
	end
end

"""
	prepare_alpha(file::String)

Parse the times of the BLOG inference output, build the average number of
queries needed to amortise the additional offline overhead and write the
results into a new `.csv` file.
"""
function prepare_alpha(file::String)
	if !isfile(file)
		@warn "File '$file' does not exist and is ignored."
		return
	end

	new_file_1 = replace(file, ".csv" => "-offline-prepared-all.csv")
	new_file_2 = replace(file, ".csv" => "-offline-prepared-avg.csv")
	if isfile(new_file_1)
		@warn "File '$new_file_1' already exists and is ignored."
		return
	elseif isfile(new_file_2)
		@warn "File '$new_file_2' already exists and is ignored."
		return
	end

	averages = Dict()
	open(file, "r") do io
		readline(io) # Remove header
		for line in readlines(io)
			cols = split(line, ",")
			algo = match(r"-cp=([a-zA-Z]+)-", cols[2])[1]
			d = parse(Int, match(r"-d1?=(\d+)-", cols[2])[1])
			p = match(r"-p=(\d+)-", cols[2])[1]
			p = parse(Float64, string(p[1], ".", p[2:end]))
			eps = match(r"-eps=(\d+)-", cols[2])[1]
			eps = parse(Float64, string(eps[1], ".", eps[2:end]))
			time = nanos_to_millis(parse(Float64, cols[12]))
			haskey(averages, p) || (averages[p] = Dict())
			haskey(averages[p], d) || (averages[p][d] = Dict())
			haskey(averages[p][d], eps) || (averages[p][d][eps] = Dict())
			haskey(averages[p][d][eps], algo) || (averages[p][d][eps][algo] = [])
			push!(averages[p][d][eps][algo], time)
		end
	end

	offline_times = Dict()
	open(replace(file, "_stats" => ""), "r") do io
		readline(io) # Remove header
		for line in readlines(io)
			cols = split(line, ",")
			algo = cols[2]
			d = parse(Int, cols[4])
			p = parse(Float64, cols[5])
			# Epsilon must be parsed from name as cols[3] is always 0.0 for ACP
			eps = match(r"-eps=(\d+)-", cols[1])[1]
			eps = parse(Float64, string(eps[1], ".", eps[2:end]))
			cp_time = parse(Float64, cols[15])
			haskey(offline_times, p) || (offline_times[p] = Dict())
			haskey(offline_times[p], d) || (offline_times[p][d] = Dict())
			haskey(offline_times[p][d], eps) || (offline_times[p][d][eps] = Dict())
			haskey(offline_times[p][d][eps], algo) || (offline_times[p][d][eps][algo] = [])
			push!(offline_times[p][d][eps][algo], cp_time)
		end
	end

	open(new_file_1, "a") do io
		write(io, "d,p,eps,gain,overhead,alpha\n")
		for (p, ds) in averages
			for (d, epss) in ds
				for (eps, _) in epss
					gain = averages[p][d][eps]["ACP"] .- averages[p][d][eps]["EACP"]
					overhead = offline_times[p][d][eps]["EACP"] .- offline_times[p][d][eps]["ACP"]
					alphas = round.(overhead ./ gain, digits=2)
					for (index, alpha) in enumerate(alphas)
						write(io, string(
							d, ",",
							p, ",",
							eps, ",",
							gain[index], ",",
							overhead[index], ",",
							alpha, "\n"
						))
					end
				end
			end
		end
	end

	open(new_file_2, "a") do io
		write(io, "d,p,eps,min_alpha,max_alpha,mean_alpha,median_alpha,std\n")
		for (p, ds) in averages
			for (d, epss) in ds
				for (eps, _) in epss
					gain = averages[p][d][eps]["ACP"] .- averages[p][d][eps]["EACP"]
					overhead = offline_times[p][d][eps]["EACP"] .- offline_times[p][d][eps]["ACP"]
					alphas = round.(overhead ./ gain, digits=2)
					write(io, string(
						d, ",",
						p, ",",
						eps, ",",
						minimum(alphas), ",",
						maximum(alphas), ",",
						mean(alphas), ",",
						median(alphas), ",",
						std(alphas), "\n"
					))
				end
			end
		end
	end
end

"""
	prepare_query_times_mimic(file::String)

Build averages over mimic runs and write the results into a new `.csv` file.
"""
function prepare_query_times_mimic(file::String)
	if !isfile(file)
		@warn "File '$file' does not exist and is ignored."
		return
	end

	new_file = replace(file, ".csv" => "-prepared.csv")
	if isfile(new_file)
		@warn "File '$new_file' already exists and is ignored."
		return
	end

	averages = Dict()
	open(file, "r") do io
		readline(io) # Remove header
		for line in readlines(io)
			cols = split(line, ",")
			algo = match(r"-cp=([a-zA-Z]+)-", cols[2])[1]
			n = parse(Int, match(r"-n=(\d+)-", cols[2])[1])
			time = nanos_to_millis(parse(Float64, cols[12]))
			haskey(averages, algo) || (averages[algo] = Dict())
			haskey(averages[algo], n) || (averages[algo][n] = [])
			push!(averages[algo][n], time)
		end
	end

	open(new_file, "a") do io
		write(io, "n,algo,min_t,max_t,mean_t,median_t,std\n")
		for (algo, ns) in averages
			for (n, times) in ns
				# Average with timeouts does not work
				if any(t -> isnan(t), times)
					@warn "Ignoring $algo with d=$d due to NaN values."
					continue
				end
				write(io, string(
					n, ",",
					algo, ",",
					minimum(times), ",",
					maximum(times), ",",
					mean(times), ",",
					median(times), ",",
					std(times), "\n"
				))
			end
		end
	end
end

"""
	prepare_quotient_mimic(file::String)

Build quotients of new and old query results and write the results into a new
`.csv` file.
"""
function prepare_quotient_mimic(file::String)
	if !isfile(file)
		@warn "File '$file' does not exist and is ignored."
		return
	end

	new_file = replace(file, ".csv" => "-prepared.csv")
	if isfile(new_file)
		@warn "File '$new_file' already exists and is ignored."
		return
	end

	averages = Dict()
	open(file, "r") do io
		readline(io) # Remove header
		for line in readlines(io)
			cols = split(line, ",")
			algo = cols[3]
			algo == "EACP" || continue
			eps = parse(Float64, cols[4])
			n = parse(Int, match(r"-n=(\d+)-", cols[1])[1])
			quotient = match(r"true=(\d\.\d+);false=(\d\.\d+)", cols[17])
			# Nothing for "timeout" and "true=NaN;false=NaN"
			isnothing(quotient) && continue
			q1, q2 = parse(Float64, quotient[1]), parse(Float64, quotient[2])
			haskey(averages, eps) || (averages[eps] = Dict())
			haskey(averages[eps], n) || (averages[eps][n] = [])
			push!(averages[eps][n], q1)
			push!(averages[eps][n], q2)
		end
	end

	open(new_file, "a") do io
		write(io, "n,eps,min_q,max_q,mean_q,median_q,std\n")
		for (eps, ns) in averages
			for (n, quotients) in ns
				write(io, string(
					n, ",",
					eps, ",",
					minimum(quotients), ",",
					maximum(quotients), ",",
					mean(quotients), ",",
					median(quotients), ",",
					std(quotients), "\n"
				))
			end
		end
	end
end

### Entry point ###
if abspath(PROGRAM_FILE) == @__FILE__
	prepare_query_times_main(string(@__DIR__, "/results_stats.csv"))
	prepare_query_times_appendix(string(@__DIR__, "/results_stats.csv"))
	prepare_alpha(string(@__DIR__, "/results_stats.csv"))
	prepare_quotient_main(string(@__DIR__, "/results.csv"))
	prepare_query_times_mimic(string(@__DIR__, "/results-mimic_stats.csv"))
	prepare_quotient_mimic(string(@__DIR__, "/results-mimic.csv"))
end