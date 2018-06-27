.DEFAULT_GOAL := help

DBT_MODEL_IMAGE_NAME := bufferapp/churnado-dbt:latest

help:
	@echo -e "Usage: \tmake [TARGET]\n"
	@echo -e "Targets:"
	@echo -e "  dbt-build                  Build dbt model Dockerfile"
	@echo -e "  dbt-run                    Runs the dbt model"
	@echo -e "  dbt-dev                    Open a shell with dbt"

dbt-run:
	docker run --rm -it -v $(PWD)/dbt:/dbt --env-file .env $(DBT_MODEL_IMAGE_NAME)

dbt-dev:
	docker run --rm -it -v $(PWD)/dbt:/dbt --env-file .env $(DBT_MODEL_IMAGE_NAME) /bin/bash

dbt-build:
	docker build -t $(DBT_MODEL_IMAGE_NAME) dbt
