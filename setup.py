from setuptools import setup, find_namespace_packages

setup(
    name="bifrost_whats_my_species",
    version="2.2.11",
    description="Datahandling functions for bifrost (later to be API interface)",
    url="https://github.com/ssi-dk/bifrost_whats_my_species",
    author="Kim Ng, Martin Basterrechea",
    author_email="kimn@ssi.dk",
    packages=find_namespace_packages(),
    install_requires=[
        "bifrostlib >= 2.1.9",
    ],
    package_data={"bifrost_whats_my_species": ["config.yaml", "pipeline.smk"]},
    include_package_data=True,
)
