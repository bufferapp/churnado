.DEFAULT_GOAL := help

help:
	@echo -e "Usage: \tmake [TARGET]\n"
	@echo -e "Targets:"
	@echo -e "  dbt-run                    Runs the dbt model"
	@echo -e "  dbt-dev                    Open a shell with dbt"

dbt-run:
	docker run --rm -it -v $(PWD)/dbt:/dbt --env-file .env davidgasquez/dbt:latest dbt run --profiles-dir .

dbt-dev:
	docker run --rm -it -v $(PWD)/dbt:/dbt --env-file .env davidgasquez/dbt:latest /bin/bash
