-- No-op. users.last_login_at is already created by 000001; this migration used to ADD it again and failed
-- on any database that applied the files in order. The version number is kept so history stays stable.
SELECT 1;
