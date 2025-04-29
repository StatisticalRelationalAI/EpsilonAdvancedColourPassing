using DataFrames, Dates, Random, StatsBase

@isdefined(DataBase)          || include(string(@__DIR__, "/database/database.jl"))
@isdefined(dataframe_to_num!) || include(string(@__DIR__, "/database/dataframes.jl"))
@isdefined(learn_pfg!)        || include(string(@__DIR__, "/database/learning.jl"))
@isdefined(save_to_file)      || include(string(@__DIR__, "/helper.jl"))
@isdefined(Query)             || include(string(@__DIR__, "/queries.jl"))

"""
	run_generation(output_dir=string(@__DIR__, "/../instances/input/"), seed=123)

Run the instance generation procedure to generate the MIMIC IV instances.
"""
function run_generation(
	output_dir=string(@__DIR__, "/../instances/mimic/"),
	seed=123
)
	Random.seed!(seed)

	patient_file = string(@__DIR__, "/../instances/mimic/patients.csv")
	treatment_file = string(@__DIR__, "/../instances/mimic/procedures_icd.csv")

	radiuses = [0.1] # Radius for DBSCAN
	num_patients = [4000]
	# num_queries = 3

	for eps in radiuses
		e_str = replace(string(eps), "." => "")
		for n in num_patients
			@info "Generating MIMIC-IV model with eps=$eps and n=$n..."
			f_name = string(output_dir, "mimic-eps=$e_str-n=$n-seed=$seed.ser")
			isfile(f_name) && continue

			# subject_id, gender, anchor_age, anchor_year, anchor_year_group, dod
			patients = load_df(patient_file)
			# Remove unnecessary columns
			select!(patients, Not([:anchor_year, :anchor_year_group, :dod]))
			# Transform id to String and remaining values to Boolean values
			transform!(patients, :subject_id => ByRow(x -> string(x)) => :subject_id)
			transform!(patients, :gender => ByRow(x -> x == "F") => :gender)
			transform!(patients, :anchor_age => ByRow(x -> x >= 50) => :anchor_age)

			# subject_id, hadm_id, seq_num, chartdate, icd_code, icd_version
			treatments = load_df(treatment_file)
			# Reduce ICD codes to version 9
			treatments = filter(row -> row.icd_version != 10, treatments)
			# Remove unnecessary columns
			select!(treatments, Not([:hadm_id, :seq_num, :chartdate, :icd_version]))
			# Transform id to String and use only first two chars of ICD codes
			transform!(treatments, :subject_id => ByRow(x -> string(x)) => :subject_id)
			transform!(treatments, :icd_code => ByRow(x -> string(x)[1:2]) => :icd_code)
			# Remove duplicate rows
			treatments = unique(treatments)

			# Prune to handle complexity
			patients = first(patients, n)
			treatments = filter(row -> row.subject_id in patients.subject_id, treatments)

			er = Schema()
			e_patient = Entity("patient")
			add_attribute!(e_patient, Attribute("gender", range(patients, "gender")))
			add_attribute!(e_patient, Attribute("anchor_age", range(patients, "anchor_age")))
			add_entity!(er, e_patient)
			e_treatment = Entity("treatment")
			add_entity!(er, e_treatment)
			add_relationship!(er, Relationship("treat", (e_patient, e_treatment), ManyToMany))

			db = DataBase(er)
			add_table!(db, "patient", patients)
			add_table!(db, "treatment", unique(DataFrame(icd_code = treatments.icd_code)))
			add_table!(db, "treat", treatments)
			set_ids!(db, "patient", [:subject_id])
			set_ids!(db, "treatment", [:icd_code])
			set_ids!(db, "treat", [:subject_id, :icd_code])

			@info "\tNumber of patients:   $(nrow(patients))"
			@info "\tNumber of treatments: $(nrow(treatments))"

			mappings = compute_clusters!(db, eps)
			fj = full_join(db)
			pfg = empty_pfg(db, fj)
			fg = add_potentials(pfg, db, mappings, fj)
			queries = [Query(name(rv)) for rv in rvs(fg)]
			save_to_file((fg, queries), f_name)
		end
	end
end

### Entry point ###
if abspath(PROGRAM_FILE) == @__FILE__
	start = Dates.now()

	run_generation()

	@info "=> Start:      $start"
	@info "=> End:        $(Dates.now())"
	@info "=> Total time: $(Dates.now() - start)"
end