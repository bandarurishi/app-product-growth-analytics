-- ============================================================================
-- 01_schema_setup.sql
-- Project: App Product Growth & A/B Experimentation Analytics
-- Purpose: Schema definitions, constraints, and performance indexes
-- Target Engines: PostgreSQL, MySQL 8+, SQLite, DuckDB, MS SQL Server
-- ============================================================================

-- Drop existing tables if re-running
DROP TABLE IF EXISTS fact_events;
DROP TABLE IF EXISTS dim_users;

-- ----------------------------------------------------------------------------
-- 1. Dimension Table: dim_users
-- Captures user attributes, acquisition attribution, and A/B test assignment
-- ----------------------------------------------------------------------------
CREATE TABLE dim_users (
    user_id VARCHAR(50) PRIMARY KEY,
    signup_date DATE NOT NULL,
    signup_timestamp TIMESTAMP NOT NULL,
    channel VARCHAR(100) NOT NULL,
    device_os VARCHAR(50) NOT NULL,
    app_version VARCHAR(50) NOT NULL,
    ab_test_group VARCHAR(50) NOT NULL,  -- 'Control_A' vs. 'Variant_B'
    country VARCHAR(100) NOT NULL
);

-- ----------------------------------------------------------------------------
-- 2. Fact Table: fact_events
-- Granular clickstream event logs representing user touchpoints
-- ----------------------------------------------------------------------------
CREATE TABLE fact_events (
    event_id VARCHAR(50) PRIMARY KEY,
    user_id VARCHAR(50) NOT NULL,
    session_id VARCHAR(100) NOT NULL,
    event_timestamp TIMESTAMP NOT NULL,
    event_name VARCHAR(100) NOT NULL,
    session_duration_sec INT DEFAULT 0,
    feature_used VARCHAR(100),
    CONSTRAINT fk_events_user FOREIGN KEY (user_id) REFERENCES dim_users(user_id)
);

-- ----------------------------------------------------------------------------
-- 3. High-Performance Analytical Indexes
-- Optimized for funnel queries, user session joins, and cohort aggregations
-- ----------------------------------------------------------------------------
CREATE INDEX idx_events_user_id ON fact_events(user_id);
CREATE INDEX idx_events_timestamp ON fact_events(event_timestamp);
CREATE INDEX idx_events_name_time ON fact_events(event_name, event_timestamp);
CREATE INDEX idx_users_cohort ON dim_users(signup_date, ab_test_group);
CREATE INDEX idx_users_channel_device ON dim_users(channel, device_os);

-- Comment / Metadata Documentation
-- Supported event types:
--   1. 'app_open'           : User initiates app session
--   2. 'signup_initiated'   : User taps registration / CTA button
--   3. 'signup_completed'   : User verifies credentials (A/B Test Target)
--   4. 'kyc_initiated'      : User starts identity verification
--   5. 'kyc_completed'      : User documents approved (Critical friction step)
--   6. 'first_core_action'  : Activation milestone (First trade / order / stream)
--   7. 'repeat_action'      : Ongoing retained user engagement
