FROM davidgasquez/dbt:0.10.0

ENV REDSHIFT_ENDPOINT='r'
ENV REDSHIFT_DB_PORT='r'
ENV REDSHIFT_USER='r'
ENV REDSHIFT_PASSWORD='r'
ENV REDSHIFT_DB_NAME='r'

COPY . /dbt

RUN ["dbt", "deps", "--profiles-dir", "."]

CMD ["dbt", "run", "--profiles-dir", "."]
