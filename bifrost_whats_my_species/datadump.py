from bifrostlib import common
from bifrostlib.datahandling import Sample
from bifrostlib.datahandling import SampleComponentReference
from bifrostlib.datahandling import SampleComponent
from bifrostlib.datahandling import Category
from typing import Dict
import os


def extract_bracken_sorted(
    species_detection: Category, results: Dict, bracken_file: str
) -> None:
    """
    Parse sorted Bracken output (filename provided by Snakemake).
    Extract top 1–2 species and their fractions.
    """
    file_name = os.path.basename(bracken_file)
    file_key = common.json_key_cleaner(file_name)

    results[file_key] = {}

    with open(bracken_file, "r", encoding="utf-8") as fh:
        buffer = fh.readlines()

    # Skip header
    entries = buffer[1:]

    for i in range(min(2, len(entries))):
        cols = entries[i].rstrip("\n").split("\t")

        species_name = cols[0]
        taxonomy_id = cols[1]
        taxonomy_lvl = cols[2]
        kraken_assigned = cols[3]
        added_reads = cols[4]
        new_est_reads = cols[5]
        fraction = float(cols[6])

        results[file_key][f"species_{i+1}_name"] = species_name
        results[file_key][f"species_{i+1}_taxonomy_id"] = taxonomy_id
        results[file_key][f"species_{i+1}_taxonomy_lvl"] = taxonomy_lvl
        results[file_key][f"species_{i+1}_kraken_assigned_reads"] = kraken_assigned
        results[file_key][f"species_{i+1}_added_reads"] = added_reads
        results[file_key][f"species_{i+1}_new_est_reads"] = new_est_reads
        results[file_key][f"species_{i+1}_fraction"] = fraction


def species_math(
    species_detection: Category, results: Dict, bracken_file: str
) -> None:
    """
    Compute percent_classified_species_1/2 and percent_unclassified.
    """
    file_key = common.json_key_cleaner(os.path.basename(bracken_file))
    r = results[file_key]

    # Species 1
    if "species_1_fraction" in r:
        species_detection["summary"]["percent_classified_species_1"] = r["species_1_fraction"]
        species_detection["summary"]["name_classified_species_1"] = r["species_1_name"]

    # Species 2
    if "species_2_fraction" in r:
        species_detection["summary"]["percent_classified_species_2"] = r["species_2_fraction"]
        species_detection["summary"]["name_classified_species_2"] = r["species_2_name"]

    # Percent classified = sum of fractions
    total_fraction = 0.0
    if "species_1_fraction" in r:
        total_fraction += r["species_1_fraction"]
    if "species_2_fraction" in r:
        total_fraction += r["species_2_fraction"]

    species_detection["summary"]["percent_classified"] = total_fraction
    species_detection["summary"]["percent_unclassified"] = 1.0 - total_fraction

    # Detected species = species_1
    if "species_1_name" in r:
        species_detection["summary"]["detected_species"] = r["species_1_name"]


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


def datadump(samplecomponent_ref_json: Dict):
    samplecomponent_ref = SampleComponentReference(value=samplecomponent_ref_json)
    samplecomponent = SampleComponent.load(samplecomponent_ref)
    sample = Sample.load(samplecomponent.sample)

    # Use Snakemake input directly
    bracken_file = snakemake.input.bracken_report

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

    extract_bracken_sorted(
        species_detection,
        samplecomponent["results"],
        bracken_file,
    )

    species_math(
        species_detection,
        samplecomponent["results"],
        bracken_file,
    )

    set_sample_species(species_detection, sample)

    samplecomponent.set_category(species_detection)
    sample.set_category(species_detection)
    samplecomponent.save_files()

    common.set_status_and_save(sample, samplecomponent, "Success")

    with open(
        os.path.join(samplecomponent["component"]["name"], "datadump_complete"),
        "w+",
        encoding="utf-8",
    ) as fh:
        fh.write("done")


datadump(
    snakemake.params.samplecomponent_ref_json,
)

