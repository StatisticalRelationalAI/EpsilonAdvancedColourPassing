@enum Cardinality OneToOne OneToMany ManyToOne ManyToMany

struct Attribute
	name::AbstractString
	range::Vector{Any}
	Attribute(name::AbstractString) = new(name, [])
	Attribute(name::AbstractString, range::Vector) = new(name, range)
end

struct Entity
	name::AbstractString
	attributes::Dict{AbstractString, Attribute}
	Entity(name::AbstractString) = new(name, Dict{AbstractString, Attribute}())
end

struct Relationship
	name::AbstractString
	entities::Tuple{Entity, Entity}
	cardinality::Cardinality
end

struct Schema
	entities::Dict{AbstractString, Entity}
	relationships::Dict{AbstractString, Relationship}
	Schema() = new(
		Dict{AbstractString, Entity}(),
		Dict{AbstractString, Relationship}()
	)
end

"""
	add_entity!(schema::Schema, entity::Entity)::Schema

Add an entity `entity` to a given schema `schema`.
Return `schema` after modification.
"""
function add_entity!(schema::Schema, entity::Entity)::Schema
	schema.entities[entity.name] = entity
	return schema
end

"""
	get_entity(schema::Schema, name::AbstractString)::Entity

Return the entity with name `name` from a given schema `schema`.
Note: Assumes that the entity exists.
"""
function get_entity(schema::Schema, name::AbstractString)::Entity
	return schema.entities[name]
end

"""
	has_entity(schema::Schema, name::AbstractString)::Bool

Check whether a given schema `schema` contains an entity with name `name`.
"""
function has_entity(schema::Schema, name::AbstractString)::Bool
	return haskey(schema.entities, name)
end

"""
	entities(schema::Schema)::Base.ValueIterator

Return all entities of a given schema `schema`.
"""
function entities(schema::Schema)::Base.ValueIterator
	return values(schema.entities)
end

"""
	add_relationship!(schema::Schema, relation::Relationship)::Schema

Add a relationship `relation` to a given schema `schema`.
Return `schema` after modification.
"""
function add_relationship!(schema::Schema, relation::Relationship)::Schema
	schema.relationships[relation.name] = relation
	return schema
end

"""
	get_relationship(schema::Schema, name::AbstractString)::Relationship

Return the relationship with name `name` from a given schema `schema`.
Note: Assumes that the relationship exists.
"""
function get_relationship(schema::Schema, name::AbstractString)::Relationship
	return schema.relationships[name]
end

"""
	has_relationship(schema::Schema, name::AbstractString)::Bool

Check whether a given schema `schema` contains a relationship with name `name`.
"""
function has_relationship(schema::Schema, name::AbstractString)::Bool
	return haskey(schema.relationships, name)
end

"""
	relationships(schema::Schema)::Base.ValueIterator

Return all relationships of a given schema `schema`.
"""
function relationships(schema::Schema)::Base.ValueIterator
	return values(schema.relationships)
end

"""
	add_attribute!(entity::Entity, attribute::Attribute)::Entity

Add an attribute `attribute` to a given entity `entity`.
Return `entity` after modification.
"""
function add_attribute!(entity::Entity, attribute::Attribute)::Entity
	entity.attributes[attribute.name] = attribute
	return entity
end

"""
	name(entity::Entity)::AbstractString

Return the name of a given entity `entity`.
"""
function name(entity::Entity)::AbstractString
	return entity.name
end

"""
	attributes(entity::Entity)::Base.ValueIterator

Return all attributes of a given entity `entity`.
"""
function attributes(entity::Entity)::Base.ValueIterator
	return values(entity.attributes)
end

"""
	name(attribute::Attribute)::AbstractString

Return the name of a given attribute `attribute`.
"""
function name(attribute::Attribute)::AbstractString
	return attribute.name
end

"""
	range(attribute::Attribute)::Vector{Any}

Return the range of a given attribute `attribute`.
"""
function range(attribute::Attribute)::Vector{Any}
	return attribute.range
end

"""
	name(relationship::Relationship)::AbstractString

Return the name of a given relationship `relationship`.
"""
function name(relationship::Relationship)::AbstractString
	return relationship.name
end

"""
	entities(relationship::Relationship)::Tuple{Entity}

Return all entities of a given relationship `relationship`.
"""
function entities(relationship::Relationship)::Tuple{Entity, Entity}
	return relationship.entities
end

"""
	cardinality(relationship::Relationship)::Tuple{Int, Int}

Return the cardinality of a given relationship `relationship`.
"""
function cardinality(relationship::Relationship)::Cardinality
	return relationship.cardinality
end

function Base.show(io::IO, attr::Attribute)
	print(io, string(
		attr.name,
		"[",
		join(attr.range, ", "),
		"]"
	))
end

function Base.show(io::IO, entity::Entity)
	print(io, string(
		entity.name,
		"(",
		join(map(attr -> name(attr), attributes(entity)), ", "),
		")"
	))
end

function Base.show(io::IO, relationship::Relationship)
	es = entities(relationship)
	@assert length(es) == 2
	c = cardinality(relationship)
	lc, rc = "", ""
	if c == OneToOne
		lc = "1"
		rc = "1"
	elseif c == OneToMany
		lc = "1"
		rc = "n"
	elseif c == ManyToOne
		lc = "n"
		rc = "1"
	elseif c == ManyToMany
		lc = "n"
		rc = "m"
	end
	print(io, string(
		name(es[1]),
		" -", lc, "- ",
		name(relationship),
		" -", rc, "- ",
		name(es[2]),
	))
end

function Base.show(io::IO, schema::Schema)
	print(io, "Entities:\n")
	for entity in entities(schema)
		print(io, string("\t", entity, "\n"))
	end
	print(io, "Relationships:\n")
	for relationship in relationships(schema)
		print(io, string("\t", relationship, "\n"))
	end
end