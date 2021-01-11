# This is intended to run in Local Development (dev) and Github Actions (test/prod)
# BUILD_ENV options (dev, test, prod) dev for local testing and test for github actions testing on prod ready code
ARG BUILD_ENV="prod"
ARG MAINTAINER="kimn@ssi.dk;"
ARG BIFROST_COMPONENT_NAME="bifrost_whats_my_species"
ARG FORCE_DOWNLOAD=true


#---------------------------------------------------------------------------------------------------
# Programs for all environments
#---------------------------------------------------------------------------------------------------
FROM continuumio/miniconda3:4.8.2 as build_base
ONBUILD ARG BIFROST_COMPONENT_NAME
ONBUILD ARG BUILD_ENV
ONBUILD ARG MAINTAINER
ONBUILD LABEL \
    BIFROST_COMPONENT_NAME=${BIFROST_COMPONENT_NAME} \
    description="Docker environment for ${BIFROST_COMPONENT_NAME}" \
    environment="${BUILD_ENV}" \
    maintainer="${MAINTAINER}"
ONBUILD RUN \
    conda install -yq -c conda-forge -c bioconda -c default snakemake-minimal==5.7.1; \
    conda install -yq -c conda-forge -c bioconda -c defaults kraken==1.1.1; \
    conda install -yq -c conda-forge -c bioconda -c defaults bracken==1.0.0;


#---------------------------------------------------------------------------------------------------
# Base for dev environement
#---------------------------------------------------------------------------------------------------
FROM continuumio/miniconda3:4.8.2 as build_dev
ONBUILD ARG BIFROST_COMPONENT_NAME
ONBUILD COPY --from=build_base / /
ONBUILD COPY /components/${BIFROST_COMPONENT_NAME} /bifrost/components/${BIFROST_COMPONENT_NAME}
ONBUILD WORKDIR /bifrost/components/${BIFROST_COMPONENT_NAME}/
ONBUILD RUN \
    pip install -r requirements.txt; \
    pip install --no-cache -e file:///bifrost/lib/bifrostlib; \
    pip install --no-cache -e file:///bifrost/components/${BIFROST_COMPONENT_NAME}/

#---------------------------------------------------------------------------------------------------
# Base for production environment
#---------------------------------------------------------------------------------------------------
FROM continuumio/miniconda3:4.8.2 as build_prod
ONBUILD ARG BIFROST_COMPONENT_NAME
ONBUILD COPY --from=build_base / /
ONBUILD WORKDIR /bifrost/components/${BIFROST_COMPONENT_NAME}
ONBUILD COPY ./ ./
ONBUILD RUN \
    pip install file:///bifrost/components/${BIFROST_COMPONENT_NAME}/

#---------------------------------------------------------------------------------------------------
# Base for test environment (prod with tests)
#---------------------------------------------------------------------------------------------------
FROM continuumio/miniconda3:4.8.2 as build_test
ONBUILD ARG BIFROST_COMPONENT_NAME
ONBUILD COPY --from=build_base / /
ONBUILD WORKDIR /bifrost/components/${BIFROST_COMPONENT_NAME}
ONBUILD COPY ./ ./
ONBUILD RUN \
    pip install -r requirements.txt \
    pip install file:///bifrost/components/${BIFROST_COMPONENT_NAME}/


#---------------------------------------------------------------------------------------------------
# Additional resources
# NOTE: with dev the resources folder is copied so many resources may already exist and you can skip 
# the download step here. Code has been added for this but it should be made more general and robust
# Right now it is handled with a FORCE_DOWNLOAD variable and a directory check
#---------------------------------------------------------------------------------------------------
FROM build_${BUILD_ENV}
ONBUILD ARG BIFROST_COMPONENT_NAME
ONBUILD ARG FORCE_DOWNLOAD
ONBUILD WORKDIR /bifrost/components/${BIFROST_COMPONENT_NAME}/resources
ONBUILD RUN \
    if [ ${FORCE_DOWNLOAD} = true ]; then \
    mkdir minikraken && cd minikraken && \
    wget -q https://ccb.jhu.edu/software/kraken/dl/minikraken_20171019_8GB.tgz && \
    tar -zxf minikraken_20171019_8GB.tgz --strip-components=1 && \
    rm minikraken_20171019_8GB.tgz && \
    wget -O minikraken_100mers_distrib.txt -q https://ccb.jhu.edu/software/bracken/dl/minikraken_8GB_100mers_distrib.txt && \
    chmod +r minikraken_100mers_distrib.txt; \
    fi;


#---------------------------------------------------------------------------------------------------
# Run and entry commands
#---------------------------------------------------------------------------------------------------
WORKDIR /bifrost/components/${BIFROST_COMPONENT_NAME}
ENTRYPOINT ["python3", "-m", "bifrost_whats_my_species"]
CMD ["python3", "-m", "bifrost_whats_my_species", "--help"]
