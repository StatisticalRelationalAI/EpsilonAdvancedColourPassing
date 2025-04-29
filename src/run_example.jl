@isdefined(FactorGraph)             || include(string(@__DIR__, "/fg/factor_graph.jl"))
@isdefined(ParfactorGraph)          || include(string(@__DIR__, "/pfg/parfactor_graph.jl"))
@isdefined(color_passing)           || include(string(@__DIR__, "/fg/color_passing.jl"))
@isdefined(advanced_color_passing!) || include(string(@__DIR__, "/fg/advanced_color_passing.jl"))
@isdefined(groups_to_pfg)           || include(string(@__DIR__, "/fg/fg_to_pfg.jl"))
@isdefined(model_to_blog)           || include(string(@__DIR__, "/pfg/blog_parser.jl"))
@isdefined(add_noise!)              || include(string(@__DIR__, "/helper.jl"))

function run_simple_example()
	a = DiscreteRV("A")
	b = DiscreteRV("B")
	c = DiscreteRV("C")

	p = [
		([true,  true],  1.0),
		([true,  false], 2.0),
		([false, true],  3.0),
		([false, false], 4.0)
	]
	f1 = DiscreteFactor("f1", [a, b], p)
	f2 = DiscreteFactor("f2", [c, b], p)

	fg = FactorGraph()
	add_rv!(fg, a)
	add_rv!(fg, b)
	add_rv!(fg, c)
	add_factor!(fg, f1)
	add_factor!(fg, f2)
	add_edge!(fg, a, f1)
	add_edge!(fg, b, f1)
	add_edge!(fg, b, f2)
	add_edge!(fg, c, f2)

	@info "Running color_passing..."
	node_colors, factor_colors = color_passing(fg)
	pfg1, _ = groups_to_pfg(fg, node_colors, factor_colors)
	model_to_blog(pfg1)

	@info "Running advanced_color_passing!..."
	node_cols, factor_cols, commutatives, hists = advanced_color_passing!(fg)
	pfg2, _ = groups_to_pfg(fg, node_cols, factor_cols, commutatives, hists)
	model_to_blog(pfg2)
end

function run_simple_epsilon_example()
	epsilon = 0.1

	a = DiscreteRV("A")
	b = DiscreteRV("B")
	c = DiscreteRV("C")

	p = [
		([true,  true],  1.0),
		([true,  false], 2.0),
		([false, true],  3.0),
		([false, false], 4.0)
	]
	f1 = DiscreteFactor("f1", [a, b], p)
	f2 = DiscreteFactor("f2", [c, b], p)

	add_noise!(f2.potentials, epsilon)

	fg = FactorGraph()
	add_rv!(fg, a)
	add_rv!(fg, b)
	add_rv!(fg, c)
	add_factor!(fg, f1)
	add_factor!(fg, f2)
	add_edge!(fg, a, f1)
	add_edge!(fg, b, f1)
	add_edge!(fg, b, f2)
	add_edge!(fg, c, f2)

	@info "Running color_passing..."
	node_colors, factor_colors = color_passing(fg)
	pfg1, _ = groups_to_pfg(fg, node_colors, factor_colors)
	model_to_blog(pfg1)

	@info "Running advanced_color_passing!..."
	node_cols, factor_cols, commutatives, hists = advanced_color_passing!(fg, Dict{Factor, Int}(), epsilon)
	pfg2, _ = groups_to_pfg(fg, node_cols, factor_cols, commutatives, hists)
	model_to_blog(pfg2)
end

function run_crv_epsilon_example()
	epsilon = 0.1

	a = DiscreteRV("A")
	b = DiscreteRV("B")

	p = [
		([true,  true],  1.0),
		([true,  false], 2.0),
		([false, true],  2.0),
		([false, false], 3.0)
	]
	f = DiscreteFactor("f", [a, b], p)

	add_noise!(f.potentials, epsilon)

	fg = FactorGraph()
	add_rv!(fg, a)
	add_rv!(fg, b)
	add_factor!(fg, f)
	add_edge!(fg, a, f)
	add_edge!(fg, b, f)

	@info "Running color_passing..."
	node_colors, factor_colors = color_passing(fg)
	pfg1, _ = groups_to_pfg(fg, node_colors, factor_colors)
	model_to_blog(pfg1)

	@info "Running advanced_color_passing!..."
	node_cols, factor_cols, commutatives, hists = advanced_color_passing!(fg, Dict{Factor, Int}(), epsilon)
	pfg2, _ = groups_to_pfg(fg, node_cols, factor_cols, commutatives, hists)
	model_to_blog(pfg2)
end


if abspath(PROGRAM_FILE) == @__FILE__
	"debug" in ARGS && (ENV["JULIA_DEBUG"] = "all")

	@info "==> Running simple example..."
	run_simple_example()

	@info "==> Running simple epsilon example..."
	run_simple_epsilon_example()

	@info "==> Running CRV epsilon example..."
	run_crv_epsilon_example()
end