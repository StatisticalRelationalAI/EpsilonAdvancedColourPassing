import BayesNets

@isdefined(DataBase)                || include(string(@__DIR__, "/database.jl"))
@isdefined(FactorGraph)             || include(string(@__DIR__, "/../fg/factor_graph.jl"))
@isdefined(DiscreteRV)              || include(string(@__DIR__, "/../fg/rand_vars.jl"))
@isdefined(DiscreteFactor)          || include(string(@__DIR__, "/../fg/factors.jl"))
@isdefined(ParfactorGraph)          || include(string(@__DIR__, "/../pfg/parfactor_graph.jl"))
@isdefined(dataframe_to_num!)       || include(string(@__DIR__, "/dataframes.jl"))
@isdefined(advanced_color_passing!) || include(string(@__DIR__, "/../fg/advanced_color_passing.jl"))
@isdefined(groups_to_pfg)           || include(string(@__DIR__, "/../fg/fg_to_pfg.jl"))

"""
	learn_pfg!(db::DataBase, epsilon::Float64)::ParfactorGraph

Learn a parfactor graph from a given data base `db`.

### References
Malte Luttermann, Ralf Möller, and Mattis Hartwig.
Towards Privacy-Preserving Relational Data Synthesis via Probabilistic Relational Models.
Proceedings of the Forty-Seventh German Conference on Artificial Intelligence (KI-2024). Springer, Volume 14992, pages 175-189.
"""
function learn_pfg!(db::DataBase, epsilon::Float64)::ParfactorGraph
	# Step 1: Compute clusters for all entities and add them to the data base
	mappings = compute_clusters!(db, epsilon)
	fj = full_join(db)
	# Step 2: Create graph structure
	pfg = empty_pfg(db, fj)
	# Step 3: Learn parameters
	fg = add_potentials(pfg, db, mappings, fj)

	node_colors, factor_colors = advanced_color_passing!(fg, Dict{Factor, Int}(), epsilon)
	pfg, mapping = groups_to_pfg(fg, node_colors, factor_colors)
	return pfg
end

"""
	compute_clusters!(db::DataBase, epsilon::Float64)::Dict

Compute clusters for all entities in a given data base `db` and add them
to the corresponding tables in `db`.
For clustering, non-numeric columns are converted to numeric columns.
Return a dictionary containing for each table the mappings of numeric values
to their original values for each column in that table.
"""
function compute_clusters!(db::DataBase, epsilon::Float64)::Dict
	er = schema(db)
	mappings = Dict()
	for e in entities(er)
		df = get_table(db, name(e))
		@assert length(get_ids(db, name(e))) == 1
		id = get_ids(db, name(e))[1]
		# DBSCAN requires floating point values
		mappings[name(e)] = dataframe_to_num!(df, Float64, id)
		add_clusters!(df, id, epsilon)
	end
	return mappings
end

"""
	empty_pfg(db::DataBase, fj::DataFrame = full_join(db))::ParfactorGraph

Create the structure of a parfactor graph from a given data base `db`.
Note that the parfactor graph does not contain any potentials afterwards.
"""
function empty_pfg(db::DataBase, fj::DataFrame = full_join(db))::ParfactorGraph
	pfg = ParfactorGraph()
	# Add nodes
	er = schema(db)
	entity_to_lv = Dict{Entity, LogVar}()
	for entity in entities(er)
		d_size = num_clusters(get_table(db, name(entity)))
		lv = LogVar(
			name(entity),
			[string(lowercase(name(entity)), "_", i) for i in 1:d_size]
		)
		entity_to_lv[entity] = lv
		for attribute in attributes(entity)
			add_prv!(pfg, PRV(name(attribute), range(attribute), [lv]))
		end
	end
	for relationship in relationships(er)
		lvs = [entity_to_lv[e] for e in entities(relationship)]
		add_prv!(pfg, PRV(name(relationship), [true, false], lvs))
	end
	# Add edges
	index = 1
	for (node, parents) in learn_graph_structure(db, fj)
		prvs = [get_prv(pfg, string(parent)) for parent in parents]
		prvs = union(prvs, [get_prv(pfg, string(node))])
		f = Parfactor("f_$index", prvs, [])
		index += 1
		add_parfactor!(pfg, f)
		for prv in prvs
			add_edge!(pfg, prv, f)
		end
	end
	return pfg
end

"""
	learn_graph_structure(db::DataBase, fj::DataFrame = full_join(db))::Dict{Symbol, Vector{Symbol}}

Learn a Bayesian network structure from a given data base `db` and return
a dictionary which maps each node to its parents.
"""
function learn_graph_structure(
	db::DataBase,
	fj::DataFrame = full_join(db)
)::Dict{Symbol, Vector{Symbol}}
	df = fj[!, setdiff(
		names(fj),
		[string(x) for x in union(vcat([get_ids(db, t) for t in table_names(db)]...))]
	)]
	dataframe_to_num!(df, Int)

	params = BayesNets.GreedyHillClimbing(
		BayesNets.ScoreComponentCache(df),
		max_n_parents=6,
		prior=BayesNets.UniformPrior()
	)
	bn = BayesNets.fit(BayesNets.DiscreteBayesNet, df, params)

	return Dict(cpd.target => cpd.parents for cpd in bn.cpds)
end

"""
	add_potentials(pfg::ParfactorGraph, db::DataBase, mappings::Dict, fj::DataFrame = full_join(db))::Dict

Return the ground factor graph with potentials for a given parfactor graph
`pfg` from a given data base `db`.
"""
function add_potentials(
	pfg::ParfactorGraph,
	db::DataBase,
	mappings::Dict,
	fj::DataFrame = full_join(db)
)::FactorGraph
	fg = ground(pfg)

	for pf in parfactors(pfg)
		# For each cluster combination a configuration with potential
		potentials = Dict()
		# All entities (logvars) appearing in the parfactor
		es = collect(logvars(pf))
		# Maps each entity (logvar) to its id (column name)
		ids = Dict(e => get_ids(db, name(e))[1] for e in es)
		# Maps each entity (logvar) to its cluster
		cls = Dict(e => id_to_cluster(get_table(db, name(e)), ids[e]) for e in es)
		# Column names (PRV names) occurring in the parfactor
		cols = [name(prv) for prv in prvs(pf)]

		for row in eachrow(fj)
			# Values in id columns
			vals = Dict(e => row[id] for (e, id) in ids)
			# Corresponding cluster to values in id columns
			cluster = Dict(e => cls[e][val] for (e, val) in vals)
			!haskey(potentials, cluster) && (potentials[cluster] = Dict())
			# Configuration on attribute columns (PRVs in parfactor)
			conf = []
			for col in cols
				lvs = logvars(get_prv(pfg, col))
				if length(lvs) == 1
					push!(conf, mappings[name(lvs[1])][col][row[col]])
				else
					push!(conf, row[col])
				end
			end
			!haskey(potentials[cluster], conf) && (potentials[cluster][conf] = 0)
			potentials[cluster][conf] += 1
		end

		for i in 1:length(collect(Iterators.product([domain(lv) for lv in logvars(pf)]...)))
			f = get_factor(fg, string(name(pf), "_", i))
			str_to_lv = Dict(name(lv) => lv for lv in logvars(pf))
			lvs = reduce(union, [split(name(rv), ".")[2:end] for rv in rvs(f)], init=Set())
			key = Dict{LogVar, Int}()
			for lv in lvs
				lv_split = split(lv, "_")
				key[str_to_lv[lv_split[1]]] = parse(Int, lv_split[2])
			end
			f.potentials = Dict(join(k, ",") => Float64(v / nrow(fj)) for (k, v) in potentials[key])
			for c in Iterators.product(map(x -> range(x), rvs(f))...)
				c = join(collect(c), ",")
				!haskey(f.potentials, c) && (f.potentials[c] = 0)
			end
		end
	end
	return fg
end

"""
	full_join(db::DataBase)::DataFrame

Compute the full join of all tables in a given data base `db`.
"""
function full_join(db::DataBase)::DataFrame
	df = DataFrame()
	for rel in relational_path(schema(db))
		@assert length(entities(rel)) == 2
		e1, e2 = entities(rel)
		cp = cross_product(db, name(e1), name(e2), name(rel))
		id1, id2 = get_ids(db, name(e1))[1], get_ids(db, name(e2))[1]
		t1, t2 = get_table(db, name(e1)), get_table(db, name(e2))
		if isempty(df)
			df = t1[!, filter(x -> x != string(:cluster), names(t1))]
		end
		t2 = t2[!, filter(x -> x != string(:cluster), names(t2))]
		df = innerjoin(df, cp, on = id1 => id1)
		df = innerjoin(df, t2, on = id2 => id2)
	end
	return df
end

"""
	relational_path(schema::Schema)::Vector{Relationship}

Return a relational path, i.e., relationships ordered such that they have
overlapping entities, through a given schema `schema`.
"""
function relational_path(schema::Schema)::Vector{Relationship}
	relations = [r for r in relationships(schema)]
	isempty(relations) && return []

	path = [pop!(relations)]
	while !isempty(relations)
		found = false
		for (index, r) in enumerate(relations)
			if !isempty(intersect(entities(r), entities(last(path))))
				if contains(entities(r), entities(last(path))[2])
					push!(path, popat!(relations, index))
				else
					insert!(path, length(path), popat!(relations, index))
				end
				found = true
				break
			end
		end
		!found && error("No connected relational path found.")
	end
	return path
end

"""
	cross_product(db::DataBase, t1::String, t2::String, rel::String)::DataFrame

Compute the cross product of two tables `t1` and `t2` in a given data base `db`
and add a column named `rel` to the resulting data frame which indicates
whether the corresponding rows are in the relationship `rel`.
"""
function cross_product(db::DataBase, t1::String, t2::String, rel::String)::DataFrame
	@assert length(get_ids(db, t1)) == 1 && length(get_ids(db, t2)) == 1
	id1 = get_ids(db, t1)[1]
	id2 = get_ids(db, t2)[1]
	@assert get_ids(db, rel) == [id1, id2] || get_ids(db, rel) == [id2, id1]
	cp = crossjoin(get_table(db, t1)[!, [id1]], get_table(db, t2)[!, [id2]])
	cp[!, Symbol(rel)] = falses(nrow(cp))
	for (index, row) in enumerate(eachrow(cp))
		tmp = filter(id1 => x -> x == row[id1], get_table(db, rel))
		tmp = filter(id2 => x -> x == row[id2], tmp)
		cp[index, Symbol(rel)] = !isempty(tmp)
	end
	return cp
end