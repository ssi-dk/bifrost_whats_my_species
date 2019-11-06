FROM ssidk/bifrost-base:2.0.5

ARG version="2.0.5"
ARG last_updated="31/07/2019"
ARG name="whats_my_species"
ARG full_name="bifrost-${name}"

LABEL \
    name=${name} \
    description="Docker environment for ${full_name}" \
    version=${version} \
    resource_version=${last_updated} \
    maintainer="kimn@ssi.dk;"

#- Tools to install:start---------------------------------------------------------------------------
RUN \
    conda install -yq -c conda-forge -c bioconda -c defaults kraken==1.1.1; \
    conda install -yq -c conda-forge -c bioconda -c defaults bracken==1.0.0;
#- Tools to install:end ----------------------------------------------------------------------------

#- Source code:start -------------------------------------------------------------------------------
RUN cd /bifrost && \
    git clone --branch ${version} https://github.com/ssi-dk/${full_name}.git ${name};
#- Source code:end ---------------------------------------------------------------------------------

#- Additional resources (files/DBs): start ---------------------------------------------------------
RUN cd /bifrost_resources && \
    wget -q https://ccb.jhu.edu/software/kraken/dl/minikraken_20171019_8GB.tgz && \
    tar -zxf minikraken_20171019_8GB.tgz minikraken;
RUN cd /bifrost_resources && \
    wget -q https://ccb.jhu.edu/software/bracken/dl/minikraken_8GB_100mers_distrib.txt /bifrost_resources/minikraken/minikraken_100mers_distrib.txt && \
    chmod +r /bifrost_resources/minikraken/minikraken_100mers_distrib.txt;
#- Additional resources (files/DBs): end -----------------------------------------------------------

#- Additional initialization: start ----------------------------------------------------------------
# None
#- Additional initialization: end ------------------------------------------------------------------

#- Set up entry point:start ------------------------------------------------------------------------
ENV PATH /bifrost/${name}/:$PATH
ENTRYPOINT ["launcher.py"]
CMD ["launcher.py", "--help"]
#- Set up entry point:end --------------------------------------------------------------------------
