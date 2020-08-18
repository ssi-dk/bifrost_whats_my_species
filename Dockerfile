# This is intended to run in Github Actions
# Arg can be set to dev for testing purposes
ARG BUILD_ENV="prod"
ARG NAME="bifrost_whats_my_species"
ARG CODE_VERSION="unspecified"
ARG RESOURCE_VERSION="unspecified"
ARG MAINTAINER="kimn@ssi.dk"

# For dev build include testing modules via pytest done on github and in development.
# Watchdog is included for docker development (intended method) and should preform auto testing 
# while working on *.py files
#
# Test data is in bifrost_run_launcher:dev
#- Source code (development):start------------------------------------------------------------------
FROM ssidk/bifrost_run_launcher:dev as build_dev
ONBUILD ARG NAME
ONBUILD COPY . /${NAME}
ONBUILD WORKDIR /${NAME}
ONBUILD RUN \
    sed -i'' 's/<code_version>/'"${CODE_VERSION}"'/g' ${NAME}/config.yaml; \
    sed -i'' 's/<resource_version>/'"${RESOURCE_VERSION}"'/g' ${NAME}/config.yaml; \
    pip install -r requirements.dev.txt;
#- Source code (development):end--------------------------------------------------------------------

#- Source code (productopm):start-------------------------------------------------------------------
FROM continuumio/miniconda3:4.7.10 as build_prod
ONBUILD ARG NAME
ONBUILD WORKDIR ${NAME}
ONBUILD COPY ${NAME} ${NAME}
ONBUILD COPY setup.py setup.py
ONBUILD COPY requirements.txt requirements.txt
ONBUILD RUN \
    sed -i'' 's/<code_version>/'"${CODE_VERSION}"'/g' ${NAME}/config.yaml; \
    sed -i'' 's/<resource_version>/'"${RESOURCE_VERSION}"'/g' ${NAME}/config.yaml; \
    ls; \
    pip install -r requirements.txt
#- Source code (productopm):end---------------------------------------------------------------------

#- Use development or production to and add info: start---------------------------------------------
FROM build_${BUILD_ENV}
ARG NAME
LABEL \
    name=${NAME} \
    description="Docker environment for ${NAME}" \
    code_version="${CODE_VERSION}" \
    resource_version="${RESOURCE_VERSION}" \
    environment="${BUILD_ENV}" \
    maintainer="${MAINTAINER}"
#- Use development or production to and add info: end---------------------------------------------

#- Tools to install:start---------------------------------------------------------------------------
RUN \
    conda install -yq -c conda-forge -c bioconda -c default snakemake-minimal==5.7.1; \
    conda install -yq -c conda-forge -c bioconda -c defaults kraken==1.1.1; \
    conda install -yq -c conda-forge -c bioconda -c defaults bracken==1.0.0; \
    pip list;
#- Tools to install:end ----------------------------------------------------------------------------

#- Additional resources (files/DBs): start ---------------------------------------------------------
WORKDIR /${NAME}/resources/minikraken
RUN \
    wget -q https://ccb.jhu.edu/software/kraken/dl/minikraken_20171019_8GB.tgz && \
    tar -zxf minikraken_20171019_8GB.tgz --strip-components=1 && \
    rm minikraken_20171019_8GB.tgz
WORKDIR /${NAME}/resources/
RUN \
    wget -O minikraken_100mers_distrib.txt -q https://ccb.jhu.edu/software/bracken/dl/minikraken_8GB_100mers_distrib.txt && \
    chmod +r minikraken_100mers_distrib.txt;
#- Additional resources (files/DBs): end -----------------------------------------------------------

#- Set up entry point:start ------------------------------------------------------------------------
ENTRYPOINT ["python3", "-m", "bifrost_whats_my_species"]
CMD ["python3", "-m", "bifrost_whats_my_species", "--help"]
#- Set up entry point:end --------------------------------------------------------------------------
