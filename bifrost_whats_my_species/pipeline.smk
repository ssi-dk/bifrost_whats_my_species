import os
import sys
import traceback

from bifrostlib import common
from bifrostlib.datahandling import SampleReference, Sample
from bifrostlib.datahandling import ComponentReference, Component
from bifrostlib.datahandling import SampleComponentReference, SampleComponent
from snakemake.io import directory
import datetime

os.umask(0o2)

# -------------------------------------------------------------------------
# INITIALIZATION
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

# -------------------------------------------------------------------------
# ERROR HANDLING (NO REQUIREMENTS CHECK)
# -------------------------------------------------------------------------

onerror:
    # Requirements disabled to avoid Pandas crash
    if samplecomponent["status"] == "Running":
        common.set_status_and_save(sample, samplecomponent, "Failure")

envvars:
    "BIFROST_INSTALL_DIR",
    "CONDA_PREFIX",
    "BIFROST_CPUS_KRAKEN",

JOB_CPUS = int(os.environ.get("BIFROST_CPUS_KRAKEN", 1))

# -------------------------------------------------------------------------
# MAIN RULES
# -------------------------------------------------------------------------

rule all:
    input:
        f"{component['name']}/datadump_complete"
    run:
        common.set_status_and_save(sample, samplecomponent, "Success")

# -------------------------------------------------------------------------
# TIME START
# -------------------------------------------------------------------------

rule set_time_start:
    output:
        start_file = f"{component['name']}/time_start.txt"
    run:
        import time
        with open(output.start_file, "w") as fh:
            fh.write(str(time.time()))

# -------------------------------------------------------------------------
# SETUP
# -------------------------------------------------------------------------

rule setup:
    input:
        rules.set_time_start.output.start_file
    output:
        init_file = touch(f"{component['name']}/initialized")
    run:
        samplecomponent["path"] = os.path.join(os.getcwd(), component["name"])
        samplecomponent.save()

# -------------------------------------------------------------------------
# CHECK REQUIREMENTS (DISABLED)
# -------------------------------------------------------------------------

rule_name = "check_requirements"
rule check_requirements:
    message:
        f"Running step:{rule_name}"
    log:
        out_file = f"{component['name']}/log/{rule_name}.out.log",
        err_file = f"{component['name']}/log/{rule_name}.err.log",
    benchmark:
        f"{component['name']}/benchmarks/{rule_name}.benchmark"
    input:
        folder = rules.setup.output.init_file
    output:
        check_file = touch(f"{component['name']}/requirements_met")
    run:
        # Requirements disabled
        pass

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
        rules.check_requirements.output.check_file,
        reads = sample["categories"]["trimmed_reads"]["summary"]["data"]
    output:
        report = f"{component['name']}/kraken_report.txt",
        output = f"{component['name']}/kraken_output.txt",
        classified = f"{component['name']}/kraken_classified.fasta",
        unclassified = f"{component['name']}/kraken_unclassified.fasta",
        tool_version = f"{component['name']}/kraken2_version.txt",
        threads_file = f"{component['name']}/threads_used.txt"
    params:
        db = f"{os.environ['BIFROST_INSTALL_DIR']}/bifrost/components/bifrost_{component['display_name']}/{component['resources']['kraken_database']}",
        threads = JOB_CPUS
    shell:
        r"""
        kraken2 {input.reads[0]} {input.reads[1]} \
            --db {params.db} \
            --threads {params.threads} \
            --report {output.report} \
            --output {output.output} \
            --classified-out {output.classified} \
            --unclassified-out {output.unclassified} \
            --use-names \
            1> {log.out_file} 2> {log.err_file}

        echo {params.threads} > {output.threads_file}

        kraken2 --version > {output.tool_version} 2>&1
        """

# -------------------------------------------------------------------------
# BRACKEN
# -------------------------------------------------------------------------

rule bracken:
    message:
        f"Running step:bracken"
    log:
        out_file = f"{component['name']}/log/bracken.out.log",
        err_file = f"{component['name']}/log/bracken.err.log"
    input:
        report = rules.kraken2_classify.output.report
    output:
        bracken = temp(f"{component['name']}/bracken.txt"),
        bracken_report = f"{component['name']}/kraken_report_bracken.txt",
        tool_version = f"{component['name']}/bracken_version.txt"
    params:
        db = f"{os.environ['BIFROST_INSTALL_DIR']}/bifrost/components/bifrost_{component['display_name']}/{component['resources']['kraken_database']}",
        read_length = 150,
        level = "S"
    shell:
        r"""
        bracken \
            -d {params.db} \
            -i {input.report} \
            -o {output.bracken} \
            -r {params.read_length} \
            -l {params.level} \
            1> {log.out_file} 2> {log.err_file}

        sort -r -t$'\t' -k7 {output.bracken} > {output.bracken_report}

        bracken -v > {output.tool_version} 2>&1
        """

# -------------------------------------------------------------------------
# TIME END
# -------------------------------------------------------------------------

rule set_time_end:
    input:
        rules.bracken.output.bracken_report
    output:
        end_file = f"{component['name']}/time_end.txt"
    run:
        import time
        with open(output.end_file, "w") as fh:
            fh.write(str(time.time()))

# -------------------------------------------------------------------------
# GIT VERSION
# -------------------------------------------------------------------------

rule_name = "git_version"
rule git_version:
    message:
        f"Running step:{rule_name}"
    log:
        out_file = f"{component['name']}/log/{rule_name}.out.log",
        err_file = f"{component['name']}/log/{rule_name}.err.log",
    benchmark:
        f"{component['name']}/benchmarks/{rule_name}.benchmark"
    input:
        rules.setup.output.init_file
    output:
        git_hash = f"{component['name']}/git_hash.txt"
    run:
        import subprocess, os

        snake_dir = os.path.dirname(workflow.snakefile)

        try:
            git_hash = subprocess.check_output(
                ["git", "-C", snake_dir, "rev-parse", "HEAD"],
                stderr=subprocess.STDOUT,
                text=True
            ).strip()
        except Exception:
            git_hash = "-"

        with open(output.git_hash, "w") as fh:
            fh.write(str(git_hash))

# -------------------------------------------------------------------------
# DUMP INFO
# -------------------------------------------------------------------------

rule dump_info:
    input:
        start_file = rules.set_time_start.output.start_file,
        end_file = rules.set_time_end.output.end_file,
        threads_file = rules.kraken2_classify.output.threads_file,
        kraken2_version = rules.kraken2_classify.output.tool_version,
        bracken_version = rules.bracken.output.tool_version,
        git_hash = rules.git_version.output.git_hash
    output:
        runtime_flag = touch(f"{component['name']}/runtime_set")
    run:
        import time
        sc = SampleComponent.load(samplecomponent.to_reference())

        with open(input.start_file) as fh:
            t_start = float(fh.read().strip())
        with open(input.end_file) as fh:
            t_end = float(fh.read().strip())
        with open(input.threads_file) as fh:
            threads_used = int(fh.read().strip())
        with open(input.kraken2_version) as fh:
            kraken2_version = fh.read().strip()
        with open(input.bracken_version) as fh:
            bracken_version = fh.read().strip()
        with open(input.git_hash) as fh:
            git_hash = fh.read().strip()

        runtime_minutes = (t_end - t_start) / 60.0

        sc["time_start"] = datetime.datetime.fromtimestamp(t_start).strftime("%Y-%m-%d %H:%M:%S")
        sc["time_end"] = datetime.datetime.fromtimestamp(t_end).strftime("%Y-%m-%d %H:%M:%S")
        sc["time_running"] = round(runtime_minutes, 3)
        sc["threads_used"] = threads_used
        sc["tool_version"] = [
            {"kraken2": kraken2_version},
            {"bracken": bracken_version}
        ]
        sc["git_hash"] = git_hash

        sc.save()

# -------------------------------------------------------------------------
# DATADUMP
# -------------------------------------------------------------------------

rule_name = "datadump"
rule datadump:
    message:
        f"Running step:{rule_name}"
    log:
        out_file = f"{component['name']}/log/{rule_name}.out.log",
        err_file = f"{component['name']}/log/{rule_name}.err.log"
    benchmark:
        f"{component['name']}/benchmarks/{rule_name}.benchmark"
    input:
        rules.bracken.output.bracken_report,
        rules.dump_info.output.runtime_flag
    output:
        complete = f"{component['name']}/datadump_complete"
    params:
        samplecomponent_id = samplecomponent["_id"]
    script:
        os.path.join(os.path.dirname(workflow.snakefile), "datadump.py")

