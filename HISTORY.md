# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


## [v2_2_11] - 2021-02-24
- Fix species not being saved properly
### Changed
- bifrost_whats_my_species/datadump.yaml


## [v2_2_10] - 2021-02-18
- Fix resource version not appearing in docker image
### Changed
- .github/workflows/docker_build_and_push_to_dockerhub.yml
  - Adjusted regex, viable resources now follow this pattern "*\([a-zA-Z0-9\-\_]*\)"*
## [v2_2_9] - 2021-02-17
- Bump bifrostlib to fix datetime bug
## [v2_2_5] - 2021-02-11
### Changed
- Github actions
  - Missing resource version

## [v2_2_3] - 2021-02-11
### Changed
- Dockerfile
  - Install via -e so we know paathing which is used for finding files

## [v2_2_2] - 2020-12-17
### Notes
Fix up dockerfile and ensuring automated tests wok
### Changed
- Dockerfile
- setup.cfg
  - Updates to utilize bumpversion options

## [v2_2_1] - 2020-12-17
### Notes
Changes to use the 2_1_0 schema, organizational updates, and updates to tests to make this work. Also updated the scheme for how the docker image is developed on to be from the root for local dev.

### Added
- docs/
  - history.rst
  - index.rst
  - readme.rst
- tests/
  - test_simple.py
- HISTORY.md
- setup.cfg

### Changed
- .dockerignore
- .gitignore
- Dockerfile
- requirements.txt
- setup.py
- bifrost_whats_my_species/
  - \_\_init\_\_.py
  - \_\_main\_\_.py
  - config.yaml
  - datadump.py
  - launcher.py
  - pipeline.smk
- .github/workflows
  - docker_build_and_push_to_dockerhub.yml
  - test_standard_workflow.yml -> run_tests.yml


### Removed
- tests/test_1_standard_workflow.py
- docker-compose.dev.yaml
- docker-compose.yaml
- requirements.dev.txt