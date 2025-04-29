# Epsilon-Advanced Colour Passing

This repository contains the source code of the epsilon-advanced colour passing
algorithm that has been presented in the paper
"Approximate Lifted Model Construction"
by Malte Luttermann, Jan Speller, Marcel Gehrke, Tanya Braun, Ralf Möller, and
Mattis Hartwig (IJCAI 2025).

Our implementation uses the [Julia programming language](https://julialang.org).

## Computing Infrastructure and Required Software Packages

All experiments were conducted in a virtual machine running Ubuntu 22.04.2.
The code was run on a single core with 32GB RAM available.

We used Julia version 1.8.1 together with the following packages:
- BayesNets v3.4.1
- BenchmarkTools v1.4.0
- CSV v0.10.15
- Clustering v0.15.8
- Combinatorics v1.0.2
- DataFrames v1.6.1
- Distributions v0.25.109
- Graphs v1.9.0
- Multisets v0.4.4
- StatsBase v0.33.21

Moreover, we applied openjdk version 11.0.25 to run the (lifted) inference
algorithms, which are provided in the `.jar` file located at
`instances/ljt-v1.0-jar-with-dependencies.jar`.

## Reproducing the Results

After the required software has been installed, the experiments can be started
as follows.

### Instance Generation

First, the input instances need to be generated.
To do so, run `julia instance_generator.jl` and `julia mimic_generator.jl`
in the `src/` directory.
To be able to run `julia mimic_generator.jl`, both `patients.csv` and
`procedures_icd.csv` need to be present in the `instances/mimic/` directory
(can be downloaded at https://physionet.org/content/mimiciv/3.1/).
The input instances are then written to `instances/input/` and to
`instances/mimic/`, respectively.

### Running the Experiments

After the instances have been generated, the experiments can be started by
running `julia run_eval.jl` and `julia run_mimic.jl` in the `src/` directory.
The (lifted) inference algorithms are then directly executed by the Julia
script.
All results are written into the `results/` directory.
To create the plots, run `julia prepare_plot.jl` in the `results/` directory
to combine the obtained run times into averages and afterwards execute the
R script `plot.r` (also in the `results/` directory).
The R script will then create a bunch of `.tex` files containing the plots
of the experiments in the `results/` directory.
To generate the plots as `.pdf` files instead, set `use_tikz = FALSE` in
line 7 of `plot.r` before executing the R script `plot.r`.