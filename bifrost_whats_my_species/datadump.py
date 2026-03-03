from bifrostlib import common
from bifrostlib.datahandling import Sample
from bifrostlib.datahandling import SampleComponentReference
from bifrostlib.datahandling import SampleComponent
from bifrostlib.datahandling import Category
from typing import Dict
import os


###############################
#   HELPER FUNCTIONS (TOP LEVEL)
###############################

def split_taxon(name: str):
    parts = name.split()
    genus = parts[0]
    species = parts[1] if len(parts) > 1 else ""
    return genus, species


def is_undefined_species(species: str):
    return species.lower().startswith("sp.")


def accumulate_block(all_species, start_index):
    """
    Accumulates a block of consecutive rows starting at start_index
    using Option C rules:
    - Same genus
    - Species identical OR undefined ("sp.") OR same species group
    - Stop when encountering a different defined species or genus change
    """
    first = all_species[start_index]
    genus1, species1 = split_taxon(first["name"])
    accumulated = first["fraction_total_reads"]
    block_name = first["name"]

    idx = start_index + 1

    while idx < len(all_species):
        genus, species = split_taxon(all_species[idx]["name"])

        # Stop if genus changes
        if genus != genus1:
            break

        # Stop if both species are defined and different
        if (not is_undefined_species(species1)
            and not is_undefined_species(species)
            and species != species1):
            break

        accumulated += all_species[idx]["fraction_total_reads"]
        idx += 1

    return accumulated, idx, block_name


###############################
#   MAIN PROCESSING FUNCTIONS
###############################

def extract_bracken_sorted(species_detection: Category, results: Dict, bracken_file: str) -> None:
    file_name = os.path.basename(bracken_file)
    file_key = common.json_key_cleaner(file_name)

    results[file_key] = {}
    results[file_key]["all_species"] = []

    with open(bracken_file, "r", encoding="utf-8") as fh:
        buffer = fh.readlines()

    entries = buffer[1:]  # skip header

    for line in entries:
        cols = line.rstrip("\n").split("\t")
        results[file_key]["all_species"].append({
            "name": cols[0],
            "taxonomy_id": cols[1],
            "taxonomy_lvl": cols[2],
            "kraken_assigned_reads": cols[3],
            "added_reads": cols[4],
            "new_est_reads": cols[5],
            "fraction_total_reads": float(cols[6]),
        })


def species_math(species_detection: Category, results: Dict, bracken_file: str) -> None:
    file_key = common.json_key_cleaner(os.path.basename(bracken_file))
    all_species = results[file_key]["all_species"]

    if not all_species:
        return

    # -------------------------
    # SPECIES 1 BLOCK
    # -------------------------
    accumulated_1, next_index, name_1 = accumulate_block(all_species, 0)
    species_detection["summary"]["name_classified_species_1"] = name_1
    species_detection["summary"]["percent_classified_species_1"] = accumulated_1

    # -------------------------
    # SPECIES 2 BLOCK
    # -------------------------
    accumulated_2 = 0.0
    name_2 = None

    if next_index < len(all_species):
        accumulated_2, _, name_2 = accumulate_block(all_species, next_index)
        species_detection["summary"]["name_classified_species_2"] = name_2
        species_detection["summary"]["percent_classified_species_2"] = accumulated_2

    # -------------------------
    # TOTALS
    # -------------------------
    total_fraction = accumulated_1 + accumulated_2
    species_detection["summary"]["percent_classified"] = total_fraction
    species_detection["summary"]["percent_unclassified"] = 1.0 - total_fraction

    species_detection["summary"]["detected_species"] = name_1


def set_sample_species(species_detection: Category, sample: Sample) -> None:
    sample_info = sample.get_category("sample_info")
    if (
        sample_info is not None
        and sample_info.get("summary", {}).get("provided_species", None) is not None
    ):
        species_detection["summary"]["species"] = sample_info["summary"]["provided_species"]
    else:
        species_detection["summary"]["species"] = species_detection["summary"].get(
            "detected_species", None
        )


###############################
#   MAIN ENTRY POINT
###############################

def datadump(samplecomponent_id: str):
    #samplecomponent_ref = SampleComponentReference(value=samplecomponent_ref_json)
    samplecomponent_ref = SampleComponentReference(_id=samplecomponent_id)
    samplecomponent = SampleComponent.load(samplecomponent_ref)
    sample = Sample.load(samplecomponent.sample)

    bracken_file = snakemake.input[0]

    species_detection = samplecomponent.get_category("species_detection")
    if species_detection is None:
        species_detection = Category(
            value={
                "name": "species_detection",
                "component": {
                    "id": samplecomponent["component"]["_id"],
                    "name": samplecomponent["component"]["name"],
                },
                "summary": {},
                "report": {},
            }
        )

    extract_bracken_sorted(species_detection, samplecomponent["results"], bracken_file)
    species_math(species_detection, samplecomponent["results"], bracken_file)
    set_sample_species(species_detection, sample)

    samplecomponent.set_category(species_detection)
    sample.set_category(species_detection)
    samplecomponent.save_files()

    common.set_status_and_save(sample, samplecomponent, "Success")

    with open(
        os.path.join(samplecomponent["component"]["name"], "datadump_complete"),
        "w+", encoding="utf-8",
    ) as fh:
        fh.write("done")


datadump(
        snakemake.params.samplecomponent_id
)

