FROM ssidk/bifrost-base:2.0.5

LABEL \
    name="bifrost-whats_my_species_check" \
    description="Docker environment for whats_my_species in bifrost" \
    version="2.0.5" \
    DBversion="31/07/19" \
    maintainer="kimn@ssi.dk;"

RUN \
    conda install -yq -c conda-forge -c bioconda -c defaults kraken==1.1.1; \
    conda install -yq -c conda-forge -c bioconda -c defaults bracken==1.0.0; \
    cd /bifrost; \
    git clone https://github.com/ssi-dk/bifrost-whats_my_species.git whats_my_species;

ADD \
    https://ccb.jhu.edu/software/kraken/dl/minikraken_20171019_8GB.tgz /bifrost_resources/
RUN \
    cd /bifrost_resources/; \
    tar -zxf minikraken_20171019_8GB.tgz /bifrost/minikraken/; 


ADD \
    https://ccb.jhu.edu/software/bracken/dl/minikraken_8GB_100mers_distrib.txt /bifrost_resources/minikraken/minikraken_100mers_distrib.txt
RUN \
    chmod +r /bifrost_resources/minikraken/minikraken_100mers_distrib.txt;

ENTRYPOINT \
    [ "/bifrost/whats_my_species/launcher.py"]
CMD \
    [ "/bifrost/whats_my_species/launcher.py", "--help"]
