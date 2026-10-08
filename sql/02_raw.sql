create table raw.api_pulls (
    pull_id     bigserial primary key,
    source      text        not null,
    fetched_at  timestamptz not null default now(),
    row_count   integer     not null,
    payload     jsonb       not null
);