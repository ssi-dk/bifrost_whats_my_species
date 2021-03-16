# bifrost_whats_my_species

This component is run given a sample id already added into the bifrostDB.From this it'll pull the paired_reads and check the species by running kraken and braken on the read data against the minikraken DB. The top results of the braken output will be used to determine the detected species. I understand that the DB use can be optimized and there are plans to do this using data from our institute for species that we sequence routinely.
