# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
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