from bifrostlib import common
from bifrostlib.datahandling import Sample
from bifrostlib.datahandling import SampleComponentReference
from bifrostlib.datahandling import SampleComponent
from bifrostlib.datahandling import Category
from typing import Dict
import os


def extract_bracken_txt(species_detection: Category, results: Dict, component_name: str) -> None:
    file_name = "bracken.txt"
    file_key = common.json_key_cleaner(file_name)
    file_path = os.path.join(component_name, file_name)
    results[file_key] = {}
    with open(file_path, "r") as fh:
        buffer = fh.readlines()
    number_of_entries = min(len(buffer) - 1, 2)
    if number_of_entries > 0:  # skip first line as it's header
        for i in range(1, 1 + number_of_entries):  # skip first line as it's header
            results[file_key]["species_" + str(i) + "_name"] = buffer[i].split("\t")[0]
            results[file_key]["species_" + str(i) + "_kraken_assigned_reads"] = buffer[i].split("\t")[3]
            results[file_key]["species_" + str(i) + "_added_reads"] = buffer[i].split("\t")[4]
            results[file_key]["species_" + str(i) + "_count"] = int(buffer[i].split("\t")[5].strip())


def extract_kraken_report_bracken_txt(species_detection: Category, results: Dict, component_name: str) -> None:
    file_name = "kraken_report_bracken.txt"
    file_key = common.json_key_cleaner(file_name)
    file_path = os.path.join(component_name, file_name)
    results[file_key] = {}
    with open(file_path, "r") as fh:
        buffer = fh.readlines()
    if len(buffer) > 2:
        results[file_key]["unclassified_count"] = int(buffer[0].split("\t")[1])
        results[file_key]["root"] = int(buffer[1].split("\t")[1])


def species_math(species_detection: Category, results: Dict, component_name: str) -> None:
    kraken_report_bracken_key = common.json_key_cleaner("kraken_report_bracken.txt")
    bracken_key = common.json_key_cleaner("bracken.txt")
    if ("status" not in results[kraken_report_bracken_key] and 
        "status" not in results[bracken_key] and 
        "species_1_count" in results[bracken_key] and 
        "species_2_count" in results[bracken_key]):
        species_detection["summary"]["percent_unclassified"] = results[kraken_report_bracken_key]["unclassified_count"] / (results[kraken_report_bracken_key]["unclassified_count"] + results[kraken_report_bracken_key]["root"])
        species_detection["summary"]["percent_classified_species_1"] = results[bracken_key]["species_1_count"] / (results[kraken_report_bracken_key]["unclassified_count"] + results[kraken_report_bracken_key]["root"])
        species_detection["summary"]["name_classified_species_1"] = results[bracken_key]["species_1_name"]
        species_detection["summary"]["percent_classified_species_2"] = results[bracken_key]["species_2_count"] / (results[kraken_report_bracken_key]["unclassified_count"] + results[kraken_report_bracken_key]["root"])
        species_detection["summary"]["name_classified_species_2"] = results[bracken_key]["species_2_name"]
        species_detection["summary"]["detected_species"] = species_detection["summary"]["name_classified_species_1"]


def set_sample_species(species_detection: Category, sample: Sample) -> None:
    sample_info = sample.get_category("sample_info")
    if sample_info is not None:
        if sample_info.get("provided_species", None) is not None:
            species_detection["summary"]["species"] = sample_info["provided_species"]
    else:
        species_detection["summary"]["species"] = species_detection["summary"].get("detected_species", None)


def datadump(samplecomponent_ref_json: Dict):
    samplecomponent_ref = SampleComponentReference(value=samplecomponent_ref_json)
    samplecomponent = SampleComponent.load(samplecomponent_ref)
    sample = Sample.load(samplecomponent.sample)
    species_detection = samplecomponent.get_category("species_detection")
    if species_detection is None:
        species_detection = Category(value={
            "name": "species_detection",
            "component": {"id": samplecomponent["component"]["_id"], "name": samplecomponent["component"]["name"]},
            "summary": {},
            "report": {}
        }
        )
    extract_bracken_txt(species_detection, samplecomponent["results"], samplecomponent["component"]["name"])
    extract_kraken_report_bracken_txt(species_detection, samplecomponent["results"], samplecomponent["component"]["name"])
    species_math(species_detection, samplecomponent["results"], samplecomponent["component"]["name"])
    set_sample_species(species_detection, sample)
    samplecomponent.set_category(species_detection)
    sample.set_category(species_detection)
    samplecomponent.save_files()
    common.set_status_and_save(sample, samplecomponent, "Success")
    with open(os.path.join(samplecomponent["component"]["name"], "datadump_complete"), "w+") as fh:
        fh.write("done")

datadump(
    snakemake.params.samplecomponent_ref_json,
)
