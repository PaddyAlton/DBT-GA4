FROM ghcr.io/dbt-labs/dbt-bigquery:1.4.1

WORKDIR /dbt_project

# default to user "my_project_user"
ARG USER_NAME=my_project_user USER_UID=10000 USER_GID=10001

# create group if not existed
RUN getent group ${USER_GID} || addgroup --gid ${USER_GID} --system nonroot 
# create user same as host machine
RUN adduser --uid ${USER_UID} --gid ${USER_GID} --system \
        --home /home/${USER_NAME} ${USER_NAME} \
    && chown ${USER_UID}:${USER_GID} /dbt_project

# run subsequent instructions using the newly-created user
USER ${USER_NAME}

# copy local files into image, placing profiles.yml in the default discovery location
COPY --chown=${USER_UID}:${USER_GID} \
    profiles.yml /home/${USER_NAME}/.dbt/profiles.yml
COPY --chown=${USER_UID}:${USER_GID} \
    my_project .

# install DBT packages from my_project/packages.yml
RUN dbt deps

ENTRYPOINT [ "dbt" ]
