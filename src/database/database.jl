@isdefined(Schema) || include(string(@__DIR__, "/schema.jl"))

struct DataBase
	schema::Schema
	tables::Dict{String, DataFrame}
	ids::Dict{String, Vector{Symbol}}
	DataBase(schema::Schema) = new(
		schema,
		Dict{String, DataFrame}(),
		Dict{String, Vector{Symbol}}()
	)
end

"""
	schema(db::DataBase)::Schema

Return the schema of a given data base `db`.
"""
function schema(db::DataBase)::Schema
	return db.schema
end

"""
	tables(db::DataBase)::Base.ValueIterator

Return all tables in a given data base `db`.
"""
function tables(db::DataBase)::Base.ValueIterator
	return values(db.tables)
end

"""
	table_names(db::DataBase)::Base.KeySet

Return all table names in a given data base `db`.
"""
function table_names(db::DataBase)::Base.KeySet
	return keys(db.tables)
end

"""
	add_table!(db::DataBase, name::AbstractString, df::DataFrame)::DataBase

Add a table with name `name` and data frame `df` to data base `db`.
The `id` of the table is set to the name of the first column of `df` per
default and can be changed by calling `set_ids!`.
"""
function add_table!(db::DataBase, name::AbstractString, df::DataFrame)::DataBase
	db.tables[name] = df
	db.ids[name] = [Symbol(names(df)[1])]
	return db
end

"""
	get_table(db::DataBase, table::AbstractString)::DataFrame

Return the table with name `table` from data base `db`.
"""
function get_table(db::DataBase, table::AbstractString)::DataFrame
	return db.tables[table]
end

"""
	has_table(db::DataBase, table::AbstractString)::Bool

Check whether a table with name `table` exists in data base `db`.
"""
function has_table(db::DataBase, table::AbstractString)::Bool
	return haskey(db.tables, table)
end

"""
	get_ids(db::DataBase, table::AbstractString)::Vector{Symbol}

Return the ids of the table with name `table` from data base `db`.
"""
function get_ids(db::DataBase, table::AbstractString)::Vector{Symbol}
	return db.ids[table]
end

"""
	set_ids!(db::DataBase, table::AbstractString, ids::Vector{Symbol})

Set the ids of the table with name `table` in data base `db` to `ids`.
"""
function set_ids!(db::DataBase, table::AbstractString, ids::Vector{Symbol})
	db.ids[table] = ids
end

function Base.show(io::IO, db::DataBase)
	print(io, "== DataBase ==\n")
	print(io, "=> Schema:\n")
	print(io, string(db.schema, "\n"))
	print(io, "=> Tables:\n")
	for (name, table) in db.tables
		print(io, string("\t", name, ":\n"))
		print(io, string("\t", table, "\n"))
	end
end