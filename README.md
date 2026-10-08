# UN Humanitarian Funding Analytics

## Introduction

My brief stint as a student volunteer working at beach adoptions, special-needs homes and pediatric wards made me deeply aware of how essential nonprofit services are and how much they rely on well-allocated funding. I often wondered how these organizations secured the resources needed for daily operations.

That curiosity became the foundation of this project. By analyzing humanitarian funding data, I wanted to understand how financial resources move through the nonprofit and humanitarian ecosystem, how donor behavior changes over time, and whether data could reveal patterns, gaps, or opportunities in the way funding is distributed.

At its core, this project aims to bridge field experience with data engineering and analytics, using real-world funding data to better understand the financial systems that support humanitarian work.

## Overview

This project is an end-to-end data engineering and analytics pipeline built around United Nations humanitarian funding data.

The pipeline retrieves data from live UN Office for the Coordination of Humanitarian Affairs (OCHA) APIs, stores the raw API responses in PostgreSQL, transforms and cleans the data through staging views, and loads structured data into a core analytical layer.

The current analysis focuses on donor behavior within the Country-Based Pooled Funds (CBPF) system. SQL analytics are used to investigate donor contributions, funding trends, donor concentration, fund preferences, pledge fulfillment, and the time between a pledge and its eventual payment.

The project is containerized with Docker and includes automated data refresh through cron jobs.


## Technology Stack

The project uses:

- **Python** for API extraction and pipeline orchestration.
- **PostgreSQL** for data storage, transformation, and analytics.
- **SQL** for data modeling and analytical queries.
- **Docker** for containerization.
- **Cron** for scheduled pipeline execution.
- **Requests** for API requests.
- **Psycopg** for PostgreSQL connectivity.
- **python-dotenv** for environment configuration.

## Data Sources

The primary data source is the United Nations Office for the Coordination of Humanitarian Affairs (OCHA).

The current pipeline works with three CBPF API sources:

- **Pooled Funds** — information about country-based pooled funds.
- **CBPF Contributions** — donor pledges and payments made to pooled funds.
- **CBPF Projects** — project-level funding information.

CBPF contributions are the primary dataset used for donor behavior analysis.

The project also investigated the Central Emergency Response Fund (CERF). CERF allocation data is available through an OCHA endpoint, while a corresponding CERF contributions endpoint was not identified during development.

Unlike a static CSV dataset, the live APIs return the current state of their underlying tables. The APIs do not provide a reliable modified-at field, so the pipeline uses row hashes to detect changes between successive pulls.

## Data Pipeline

The pipeline follows an ELT architecture:

```text
Live OCHA APIs
      ↓
    RAW
      ↓
   STAGING
      ↓
     CORE
      ↓
  SQL ANALYTICS
      ↓
 Visualizations
```

The **raw layer** stores API responses exactly as received using PostgreSQL `jsonb`. This preserves the original source data and creates a history of API pulls.

The **staging layer** converts raw JSON into typed fields, handles data-cleaning rules, and applies donor canonicalization.

The **core layer** contains modeled relational tables for donors, pooled funds, contributions, organizations, projects, and pipeline execution history.

The analytical SQL queries operate primarily on the core layer.

This separation keeps ingestion, cleaning, modeling, and analysis independent, making the pipeline easier to debug and extend.

## Data Quality and Cleaning

Working with live API data revealed several inconsistencies that would make direct analysis unreliable.

The same donor can appear under multiple donor codes, and some donor names contain HTML-encoded characters. The pipeline therefore maintains a donor alias mapping that converts raw donor codes into canonical donor identities while preserving the original donor code on the contribution record.

Unpaid contributions are represented by a `PaidAmt` of zero and a sentinel paid date. These values are converted into appropriate null values in the staging layer.

Historical date sentinels are also cleaned during staging rather than in the ingestion code.

A row hash is calculated from the cleaned contribution fields and is used to determine whether a contribution has been inserted, updated, or remained unchanged between API pulls.

The raw payload is always retained, so transformations can be traced back to the source data when unexpected changes occur.

## Database Architecture

PostgreSQL is organized into three main schemas.

### `raw`

The raw layer stores complete API responses.

```text
raw.api_pulls
```

Each pull records the source, timestamp, row count, pipeline run, and complete JSON payload.

### `staging`

The staging layer contains views that transform the latest raw API data into cleaned, typed records.

Examples include:

```text
staging.v_cbpf_contributions
staging.v_pooled_fund
staging.v_contribution_json
staging.v_donor_alias
staging.v_donor
```

### `core`

The core layer contains the modeled relational tables used for analysis.

```text
core.dim_pooled_fund
core.dim_donor
core.donor_alias
core.dim_organization
core.cbpf_contributions
core.cbpf_projects
core.pipeline_runs
```

The contribution table stores donor, pooled fund, fiscal year, pledged amount, paid amount, pledge date, pipeline date, paid date, row hash, and pipeline lineage information.

## Pipeline Reliability

The pipeline is designed to be safe to run repeatedly and to preserve data when something goes wrong.

Each source uses a PostgreSQL advisory lock so that overlapping executions cannot process the same source simultaneously.

API requests are retried when connection or timeout errors occur.

Raw API responses are committed separately from downstream transformations, meaning that a failed transformation does not result in the loss of the source payload.

The transformation and core update occur within a transaction, allowing a failed transformation to be rolled back without leaving the core tables partially updated.

Each pipeline execution is recorded in `core.pipeline_runs`, including its status, timestamps, rows fetched, inserted rows, updated rows, unchanged rows, and missing rows.

Rows that disappear from a subsequent API snapshot are not immediately deleted. Instead, they can be marked inactive so that historical state is preserved.

## SQL Analytics

The `sql/analytics` directory contains the analytical queries used to investigate donor behavior.

```text
sql/
└── analytics/
    ├── 00_view.sql
    ├── 01_top_donors.sql
    ├── 03_concentration.sql
    ├── 04_consistency.sql
    ├── 05_fund_preferences.sql
    ├── 06_recipient_countries.sql
    ├── 07_fulfillment.sql
    ├── 08_pledge_to_paid.sql
    ├── 09_multi_year.sql
    ├── 10_private_bucket.sql
    ├── 11_pledged_vs_paid_by_year.sql
    └── 12_fund_trends.sql
```

The analysis uses SQL concepts including joins, aggregations, common table expressions, window functions, ranking, conditional aggregation, and time-based calculations.

The questions explored include:

- Who are the largest humanitarian donors by paid funding?
- How does donor funding change from year to year?
- How concentrated is humanitarian funding among the largest donors?
- Which pooled funds receive funding from particular donors?
- How consistently do donors fulfill their pledges?
- How long does it take for pledged funding to become paid funding?
- Which contributions span multiple years?
- How do funding levels change across humanitarian funds over time?

Pledged and paid amounts are intentionally analyzed separately. Pledged amounts can include unpaid or future contributions, so they should not be interpreted as money already received.


## Repository Structure

```text
UNFunding/
│
├── data/
│   └── raw/
│       ├── probe_cbpf_contributions.json
│       ├── probe_cbpf_poolfund.json
│       ├── probe_cbpf_projects.json
│       ├── probe_cerf_allocations.json
│       └── probe_contribution.json
│
├── sql/
│   ├── analytics/
│   │   ├── 00_view.sql
│   │   ├── 01_top_donors.sql
│   │   ├── 03_concentration.sql
│   │   ├── 04_consistency.sql
│   │   ├── 05_fund_preferences.sql
│   │   ├── 06_recipient_countries.sql
│   │   ├── 07_fulfillment.sql
│   │   ├── 08_pledge_to_paid.sql
│   │   ├── 09_multi_year.sql
│   │   ├── 10_private_bucket.sql
│   │   ├── 11_pledged_vs_paid_by_year.sql
│   │   └── 12_fund_trends.sql
│   │
│   ├── 01_schemas.sql
│   ├── 02_raw.sql
│   ├── 03_core.sql
│   ├── 04_staging.sql
│   ├── 05_staging_dims.sql
│   └── yoy_change.sql
│
├── src/
│   ├── db.py
│   ├── extract.py
│   ├── inspect_api.py
│   ├── load_raw.py
│   ├── run_pipeline.py
│   └── transform.py
│
├── Dockerfile
├── docker-compose.yaml
├── crontab
├── requirements.txt
├── .env
└── README.md
```

## Running the Project

Start the PostgreSQL database and pipeline containers with:

```bash
docker compose up -d --build
```

Access the PostgreSQL database with:

```bash
docker compose exec db psql -U unfunding -d unfunding
```

The pipeline can also be executed manually from the project root:

```bash
python src/run_pipeline.py
```

Individual sources can be passed when required:

```bash
python src/run_pipeline.py poolfund contribution
```

The pipeline is designed to run automatically through cron inside the Docker container.

To inspect the scheduled job:

```bash
docker compose exec pipeline cat /etc/cron.d/pipeline
```

After modifying the pipeline code, Dockerfile, or cron configuration, rebuild the pipeline container:

```bash
docker compose up -d --build pipeline
```

## Project Status

The core data engineering pipeline is operational.

Docker and PostgreSQL are configured, the raw, staging, and core database layers have been implemented, and the CBPF pooled fund and contribution APIs are being extracted and loaded into PostgreSQL.

The pipeline includes raw data storage, transformations, donor canonicalization, row-level change detection, idempotent loading, run tracking, failure handling, and scheduled execution through cron.

The current development stage focuses on SQL analytics for donor behavior, followed by dbt models, tests, and visualizations.

## Future Work

The next stage of the project will introduce dbt models and tests on top of the core PostgreSQL tables.

Additional work will include completing project-level organization modeling, expanding the analytical visualizations, integrating CERF allocation data, and potentially introducing Airflow or Airbyte for more advanced orchestration and ingestion.

The longer-term goal is to turn the project into a reproducible analytical system that continuously ingests humanitarian funding data and makes changes in funding behavior easier to understand.

## Limitations

The project uses live API snapshots rather than a complete historical database of humanitarian funding.

The APIs do not expose a reliable modified-at timestamp, so changes are detected through comparisons between successive snapshots.

The current implementation focuses primarily on CBPF contributions. CBPF project ingestion and CERF integration are extensions of the current pipeline rather than completed analytical components.

Most importantly, funding should not be treated as equivalent to impact. The available data describes financial flows, not whether funded humanitarian projects achieved their intended outcomes.
