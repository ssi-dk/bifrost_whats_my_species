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
    Parse sorted Bracken output.
    Store ALL species rows in results[file_key]["all_species"].
    Store top 1–2 species ONLY in summary (not in results).
    """
    file_name = os.path.basename(bracken_file)
    file_key = common.json_key_cleaner(file_name)

    results[file_key] = {}
    results[file_key]["all_species"] = []

    with open(bracken_file, "r", encoding="utf-8") as fh:
        buffer = fh.readlines()

    # Skip header
    entries = buffer[1:]

    # Store ALL species rows in results
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

    # Store top 1–2 species ONLY in summary
    if len(entries) > 0:
        cols = entries[0].rstrip("\n").split("\t")
        species_detection["summary"]["name_classified_species_1"] = cols[0]
        species_detection["summary"]["percent_classified_species_1"] = float(cols[6])

    if len(entries) > 1:
        cols = entries[1].rstrip("\n").split("\t")
        species_detection["summary"]["name_classified_species_2"] = cols[0]
        species_detection["summary"]["percent_classified_species_2"] = float(cols[6])


def species_math(
    species_detection: Category, results: Dict, bracken_file: str
) -> None:
    """
    Compute percent_classified and percent_unclassified using summary fields.
    """
    s = species_detection["summary"]

    total_fraction = 0.0
    if "percent_classified_species_1" in s:
        total_fraction += s["percent_classified_species_1"]
    if "percent_classified_species_2" in s:
        total_fraction += s["percent_classified_species_2"]

    s["percent_classified"] = total_fraction
    s["percent_unclassified"] = 1.0 - total_fraction

    # Detected species = species_1
    if "name_classified_species_1" in s:
        s["detected_species"] = s["name_classified_species_1"]


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

