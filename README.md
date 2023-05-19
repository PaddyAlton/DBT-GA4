DBT-GA4
=======

Do you use Google Analytics 4, BigQuery, and DBT?

**If so, this template project is for you!**

You may or may not know that GA4 provides the ability to stream event-level data into BigQuery. If you didn't know that, [here are instructions](https://support.google.com/analytics/answer/9823238) for linking your GA4 data to your BigQuery instance.

The GA4 Export
--------------

The exported data is in a slightly curious format. [You can read about that in detail here](https://support.google.com/analytics/answer/9358801), but in short:

- a BigQuery dataset called `analytics_<your ID>` is created
- this dataset contains 'date sharded' tables: tables with a common schema, created once per day with a name like `events_YYYYMMDD`, where the suffix denotes the date of the export
- there are also special tables, `events_intraday_YYYYMMDD`, which receive a _continuous stream_ of data (albeit with some processing not yet complete)
- the data schema for these tables is also highly nested, with key/value repeated fields in many cases

This is somewhat different from the usual way of handling large amounts of data with a date[time] field, namely a date-_partitioned_ table. This is likely because your Google Tag Manager/GA4 setup is highly customisable and might evolve over time. A general schema for data exports therefore requires a great deal of flexibility.

However, such a schema is hard to use for business intelligence purposes - especially for _ad hoc_ queries. Moreover, you understand _your own_ schema and do _not_ require the same level of flexibility.

Where does DBT come into it?
----------------------------

DBT is a well-known tool for applying _in situ_ transformations of your data in your data warehouse via version-controlled, modular, templated SQL queries. It supports a wide variety of data warehouses, including BigQuery.

DBT is an excellent tool for data modelling purposes. Following the 'ELT' paradigm (Extract, Load, Transform - i.e. land your data in raw format and _then_ transform it within your warehouse) allows one to iterate on transformations while making backfilling easy. Thus, your data models can evolve over time along with your organisation's own understanding of its data.

Finally, DBT supports incremental models: concretely, it is easy to use DBT to set up a partitioned table in BigQuery and run your DBT transformations on a schedule such that only the most recent partition(s) is/are updated.

This project
------------

This project defines some DBT incremental models that

- load your GA4 export data into a series of incrementally-materialised tables
- execute transformations to normalise the schema, eliminating nesting
- yield two 'data mart' models (one for event-scoped data and the other for session-scoped data)

The tables have been set up to minimise the amount of data that will be processed every time DBT runs. This requires multiple discrete transformations, and also requires that the outputs of these transformations be stored persistently. Thus there is a storage-space tradeoff. However, BigQuery pricing tends to be weighted more heavily towards processing than storage.

This setup is probably overkill if your website doesn't have much traffic! If that is your case, it would be better to remove the incremental logic and fall back on the default `base view -> ephemeral intermediate -> materialised mart` setting defined in `dbt_project.yml` (i.e. materialising only the final 'data mart' tables). However, beyond a certain scale of daily traffic the incremental model will likely become faster and cheaper.

It is expected that you will have your own custom parameters defined, and will therefore extend these models. If your transformation logic changes, you should simply run the models in 'full refresh' mode, which will rebuild all of them from scratch. You could consider doing this as a matter of course at the point-of-deployment, but that is beyond the scope of this template.

Please note: this project contains a custom `generate_schema_name` macro, which will write models to different schemas depending on schemas defined in `dbt_project.yml` and whether the environment variable `$DBT_EXEC_PROFILE` is set to `prod` or not. 

By default, a production run would create three datasets, `dbt_base`, `dbt_intm`, and `dbt_marts`, and the models would be appropriately separated between them.

If `$DBT_EXEC_PROFILE` is set to something other than `prod` (the default is `dev`) then the environment variable will be appended to the schema/dataset name.

Getting started
---------------

You will need to fill out `profiles.yml` appropriately and add appropriate service account credentials at `config/credentials.json`. This is to authorise connectivity with BigQuery.

I've included some boilerplate infrastructure. To make the most of this you will need to install [Docker](https://docs.docker.com/get-docker/) and [Taskfile](https://taskfile.dev/installation/) (for this purpose - i.e running one-off, interactive tasks rather than a persistent application - I prefer this to Docker Compose).

If you do this, you should be able to do:
- `task build_image` to build an image for the DBT project
- `task start` to run a shell inside that image (you can then execute `dbt run` commands interactively) with volume mounting keeping your models up to date
- `task build_docs` to build the DBT documentation site
- `task serve_docs` to serve the DBT documentation site (after building it!) on `localhost:8123`


Acknowledgements
----------------

I am indebted to my previous employer, [Apolitical Group Ltd](https://apolitical.co/), for giving permission to open-source this work.

My thanks also to [@davilayang](https://github.com/davilayang) for collaborating on the original version of this project.
