create fulltext index if not exists job_name_fts_idx on jobs(job_name);
create fulltext index if not exists job_owner_fts_idx on jobs(job_owner_username);
