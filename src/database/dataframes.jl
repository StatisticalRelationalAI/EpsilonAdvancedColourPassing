using Clustering, DataFrames

IntOrFloatType = Union{Type{Int}, Type{Float64}}

"""
	add_clusters!(df::DataFrame, id::Symbol = :id, epsilon::Float64 = 0.05)

Add clusters to a given data frame `df` using the DBSCAN algorithm with the
given radius `epsilon`.
Objects in the data frame are identified by the column `id`.
The clusters are added in a new column named `cluster`, so make sure that
there is no column named `cluster` in the data frame as it will be overwritten.
"""
function add_clusters!(df::DataFrame, id::Symbol = :id, epsilon::Float64 = 0.05)
	df_input = df[:, setdiff(names(df), [string(id)])]

	if isempty(df_input)
		df[!, :cluster] = [i for i in 1:nrow(df)]
		return
	end

	points = transpose(dataframe_to_array(df_input))
	result = dbscan(Matrix(points), epsilon)
	df[!, :cluster] = result.assignments
end

"""
	clusters(df::DataFrame)

Return the clusters of a given data frame `df` as a vector of integers.
"""
function clusters(df::DataFrame)::Vector{Int}
	if !(string(:cluster) in names(df))
		return Vector{Int}()
	end
	return unique(df[!, :cluster])
end

"""
	cluster_to_ids(df::DataFrame, id::Symbol)::Dict{Int, Vector{String}}

Return a dictionary which maps each cluster of a given data frame `df` to the
IDs of the objects in that cluster.
"""
function cluster_to_ids(df::DataFrame, id::Symbol)::Dict{Int, Vector{String}}
	d = Dict{Int, Vector{String}}()
	for row in eachrow(df)
		!haskey(d, row[:cluster]) && (d[row.cluster] = Vector{String}())
		push!(d[row[:cluster]], row[id])
	end
	return d
end

"""
	id_to_cluster(df::DataFrame, id::Symbol)::Dict{String, Int}

Return a dictionary which maps each ID of a given data frame `df` to the
cluster of that object.
"""
function id_to_cluster(df::DataFrame, id::Symbol)::Dict{String, Int}
	d = Dict{String, Int}()
	for row in eachrow(df)
		d[row[id]] = row[:cluster]
	end
	return d
end

"""
	num_clusters(df::DataFrame)::Int

Return the number of unique clusters of a given data frame `df`.
"""
function num_clusters(df::DataFrame)::Int
	return length(unique(clusters(df)))
end

"""
	dataframe_to_array(df::DataFrame)::Matrix

Convert a data frame `df` to an array (matrix).
"""
function dataframe_to_array(df::DataFrame)::Matrix
	return Matrix(df)
end

"""
	dataframe_to_num!(df::DataFrame, type::IntOrFloatType, id::Symbol = :id)::Dict

Convert all columns of `df` except for the column `id` to the given type `type`
(one of `Int` or `Float64`).
Return a dictionary that maps each row to a dictionary mapping all numeric
values in that row to their original values.
"""
function dataframe_to_num!(df::DataFrame, type::IntOrFloatType, id::Symbol = :id)::Dict
	mappings = Dict()
	for col in setdiff(names(df), [string(id)])
		if typeof(col) != type
			col_to_num!(df, col, type, mappings)
		end
	end
	return mappings
end

"""
	col_to_num!(df::DataFrame, col::AbstractString, type::IntOrFloatType, m::Dict)

Convert a column `col` of a data frame `df` to the given type `type` (one of
`Int` or `Float64`).
The dictionary `m` is used to store the mappings of the new numeric values to
the original values.
"""
function col_to_num!(df::DataFrame, col::AbstractString, type::IntOrFloatType, m::Dict)
	unique_values = sort(unique(df[!, col]))
	mappings = Dict(unique_values .=> convert.(type, 1:length(unique_values)))
	m[col] = Dict(val => key for (key, val) in mappings)
	df[!, col] = map(x -> mappings[x], df[!, col])
end

"""
	range(df::DataFrame, col::AbstractString)::Vector{Any}

Return the range (i.e., the possible values) of a column `col` in a data frame
`df`.
"""
function range(df::DataFrame, col::AbstractString)::Vector{Any}
	return unique(df[!, col])
end