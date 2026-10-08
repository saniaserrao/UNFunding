create table core.dim_pooled_fund (
    pooled_fund_id        integer primary key,
    fund_name             text not null,
    fund_abbrv            text,
    fund_country_iso2     char(2),
    latitude              numeric(9,6),
    longitude             numeric(9,6),
    parent_pooled_fund_id integer references core.dim_pooled_fund (pooled_fund_id)
);

create table core.dim_donor (
    donor_code    integer primary key,
    donor_name    text not null,
    gms_donor_id  integer
);

create table core.donor_alias (
    raw_donor_code integer primary key,
    donor_code     integer not null references core.dim_donor (donor_code)
);

create table core.dim_organization (
    organization_id   integer generated always as identity primary key,
    organization_name text not null unique,
    organization_type text
);

create table core.pipeline_runs (
    run_id        integer generated always as identity primary key,
    source        text        not null,
    source_as_of  date,
    started_at    timestamptz not null default now(),
    finished_at   timestamptz,
    status        text        not null default 'running'
                  check (status in ('running', 'success', 'failed')),
    error         text,
    rows_fetched  integer,
    inserted      integer,
    updated       integer,
    unchanged     integer,
    missing       integer
);

create table core.cbpf_contributions (
    contribution_code  text primary key,
    pooled_fund_id     integer not null references core.dim_pooled_fund (pooled_fund_id),
    raw_donor_code     integer not null references core.donor_alias (raw_donor_code),
    donor_country_code text,
    fiscal_year        integer not null,
    pledge_amt         numeric(18,2),
    paid_amt           numeric(18,2),
    pledge_date        date,
    pipeline_date      date,
    paid_date          date,
    row_hash           text    not null,
    first_seen_run_id  integer not null references core.pipeline_runs (run_id),
    last_seen_run_id   integer not null references core.pipeline_runs (run_id),
    is_active          boolean not null default true
);

create table core.cbpf_projects (
    chf_project_code      text primary key,
    pooled_fund_id        integer not null references core.dim_pooled_fund (pooled_fund_id),
    organization_id       integer references core.dim_organization (organization_id),
    raw_organization_name text,
    chf_id                integer,
    project_title         text,
    allocation_year       integer,
    allocation_type       text,
    project_start_date    date,
    project_end_date      date,
    budget                numeric(18,2),
    total_direct_cost     numeric(18,2),
    total_support_cost    numeric(18,2),
    project_status        text,
    approved_date         date,
    raw                   jsonb,
    row_hash              text    not null,
    first_seen_run_id     integer not null references core.pipeline_runs (run_id),
    last_seen_run_id      integer not null references core.pipeline_runs (run_id),
    is_active             boolean not null default true
);

create index on core.cbpf_contributions (pooled_fund_id);
create index on core.cbpf_contributions (raw_donor_code);
create index on core.cbpf_contributions (fiscal_year);
create index on core.cbpf_projects (pooled_fund_id);
create index on core.cbpf_projects (organization_id);
create index on core.cbpf_projects (allocation_year);

alter table raw.api_pulls
    add column run_id integer references core.pipeline_runs (run_id);