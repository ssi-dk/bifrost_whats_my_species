import os
import sys
import traceback

from bifrostlib import common
from bifrostlib.datahandling import SampleReference, Sample
from bifrostlib.datahandling import ComponentReference, Component
from bifrostlib.datahandling import SampleComponentReference, SampleComponent

os.umask(0o2)

# -------------------------------------------------------------------------
# INITIALIZATION (no requirement checking)
# -------------------------------------------------------------------------

try:
    sample_ref = SampleReference(_id=config.get('sample_id'), name=config.get('sample_name'))
    sample = Sample.load(sample_ref)
    if sample is None:
        raise Exception("Invalid sample")

    component_ref = ComponentReference(name=config['component_name'])
    component = Component.load(reference=component_ref)
    if component is None:
        raise Exception("Invalid component")

    samplecomponent_ref = SampleComponentReference(
        name=SampleComponentReference.name_generator(sample.to_reference(), component.to_reference())
    )
    samplecomponent = SampleComponent.load(samplecomponent_ref)
    if samplecomponent is None:
        samplecomponent = SampleComponent(
            sample_reference=sample.to_reference(),
            component_reference=component.to_reference()
        )

    common.set_status_and_save(sample, samplecomponent, "Running")

except Exception:
    print(traceback.format_exc(), file=sys.stderr)
    raise Exception("Failed to initialize component")

onerror:
    common.set_status_and_save(sample, samplecomponent, "Failure")

envvars:
    "BIFROST_INSTALL_DIR",
    "CONDA_PREFIX"

# -------------------------------------------------------------------------
# MAIN RULES
# -------------------------------------------------------------------------

rule all:
    input:
        f"{component['name']}/datadump_complete"
    run:
        common.set_status_and_save(sample, samplecomponent, "Success")

rule setup:
    output:
        touch(f"{component['name']}/initialized")
    run:
        samplecomponent["path"] = os.path.join(os.getcwd(), component["name"])
        samplecomponent.save()

# -------------------------------------------------------------------------
# KRAKEN2 CLASSIFICATION
# -------------------------------------------------------------------------

rule_name = "kraken2_classify"
rule kraken2_classify:
    message:
        f"Running step:{rule_name}"
    log:
        out_file = f"{component['name']}/log/{rule_name}.out.log",
        err_file = f"{component['name']}/log/{rule_name}.err.log"
    input:
        contigs = sample["categories"]["contigs"]["summary"]["data"]
    output:
        report = f"{component['name']}/kraken_report.txt",
        output = f"{component['name']}/kraken_output.txt",
        classified = f"{component['name']}/kraken_classified.fasta",
        unclassified = f"{component['name']}/kraken_unclassified.fasta"
    params:
        db = f"{os.environ['BIFROST_INSTALL_DIR']}/bifrost/components/bifrost_{component['display_name']}/resources/minikraken2/",
        threads = 8
    shell:
        r"""
        kraken2 {input.contigs} \
            --db {params.db} \
            --threads {params.threads} \
            --report {output.report} \
            --output {output.output} \
            --classified-out {output.classified} \
            --unclassified-out {output.unclassified} \
            --use-names \
            1> {log.out_file} 2> {log.err_file}
        """

# -------------------------------------------------------------------------
# BRACKEN
# -------------------------------------------------------------------------

rule_name = "bracken"
rule bracken:
    message:
        f"Running step:{rule_name}"
    log:
        out_file = f"{component['name']}/log/{rule_name}.out.log",
        err_file = f"{component['name']}/log/{rule_name}.err.log"
    input:
        report = rules.kraken2_classify.output.report
    output:
        bracken = f"{component['name']}/bracken.txt",
        bracken_report = f"{component['name']}/kraken_report_bracken.txt"
    params:
        kmer_dist = f"{os.environ['BIFROST_INSTALL_DIR']}/bifrost/components/bifrost_{component['display_name']}/resources/minikraken2/database150mers.kmer_distrib",
        level = "S",
        threshold = 10
    shell:
        r"""
        est_abundance.py \
            -i {input.report} \
            -k {params.kmer_dist} \
            -o {output.bracken} \
            -l {params.level} \
            -t {params.threshold} \
            1> {log.out_file} 2> {log.err_file}

        sort -r -t$'\t' -k7 {output.bracken} -o {output.bracken_report}
        """
# -------------------------------------------------------------------------
# DATADUMP
# -------------------------------------------------------------------------

rule datadump:
    input:
        rules.bracken.output.bracken_report
    output:
        f"{component['name']}/datadump_complete"
    params:
        samplecomponent_ref_json = samplecomponent.to_reference().json
    script:
        os.path.join(os.path.dirname(workflow.snakefile), "datadump.py")
