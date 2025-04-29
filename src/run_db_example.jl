using DataFrames
import BayesNets

@isdefined(DataBase)          || include(string(@__DIR__, "/database/database.jl"))
@isdefined(ParfactorGraph)    || include(string(@__DIR__, "/pfg/parfactor_graph.jl"))
@isdefined(dataframe_to_num!) || include(string(@__DIR__, "/database/dataframes.jl"))
@isdefined(learn_pfg!)        || include(string(@__DIR__, "/database/learning.jl"))

patient = DataFrame(
	patient_id=["alice", "bob", "charlie", "dave", "eve"],
	#age=[">=18", ">=18", ">=18", "<18", "<18"],
	age=[true, true, true, false, false],
	#hairColour=["H", "H", "H", "D", "D"]
	hairColour=[true, true, true, false, false]
)

medication = DataFrame(
	medication_id=["m1", "m2", "m3", "m4", "m5"],
	#costs=["high", "high", "low", "low", "high"]
	costs=[true, true, false, false, true]
)

treat = DataFrame(
	patient_id=["alice", "alice", "bob", "bob", "charlie", "charlie"],
	medication_id=["m1", "m2", "m3", "m4", "m3", "m4"]
)

er = Schema()
e_patient = Entity("patient")
add_attribute!(e_patient, Attribute("age", range(patient, "age")))
add_attribute!(e_patient, Attribute("hairColour", range(patient, "hairColour")))
add_entity!(er, e_patient)
e_medication = Entity("medication")
add_attribute!(e_medication, Attribute("costs", range(medication, "costs")))
add_entity!(er, e_medication)
add_relationship!(er, Relationship("treat", (e_patient, e_medication), ManyToMany))


db = DataBase(er)
add_table!(db, "patient", patient)
add_table!(db, "medication", medication)
add_table!(db, "treat", treat)
set_ids!(db, "patient", [:patient_id])
set_ids!(db, "medication", [:medication_id])
set_ids!(db, "treat", [:patient_id, :medication_id])


pfg = learn_pfg!(db, 0.5)
println(pfg)