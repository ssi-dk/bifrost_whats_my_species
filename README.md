# bifrost_whats_my_species

This component is run given a sample id already added into the bifrostDB.From this it'll pull the paired_reads and check the species by running kraken and braken on the read data against the minikraken DB. The top results of the braken output will be used to determine the detected species. I understand that the DB use can be optimized and there are plans to do this using data from our institute for species that we sequence routinely.

## Programs: (see Dockerfile) 
```
snakemake-minimal==5.7.1;
kraken==1.1.1; 
bracken==1.0.0;
```

## Summary of c run: (see pipeline.smk and config.yaml)
```
kraken -db {params.db} {input.reads} 2> {log.err_file} | kraken-report -db {params.db} 1> {output.kraken_report}
est_abundance.py -i {input.kraken_report} -k {params.kmer_dist} -o {output.bracken} 1> {log.out_file} 2> {log.err_file}
sort -r -t$'\t' -k7 {output.bracken} -o {output.bracken}
```
