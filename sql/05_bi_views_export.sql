-- ============================================================================
-- 05_bi_views_export.sql
-- Project: App Product Growth & A/B Experimentation Analytics
-- Purpose: Analytical Views for Power BI Import / DirectQuery Consumption
--          Follows Star Schema conventions (Denormalized reporting views)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- View 1: vw_user_funnel_milestones
-- Feeds the Onboarding Funnel Dashboard with full slice-and-dice capability
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_user_funnel_milestones AS
SELECT 
    u.user_id,
    u.signup_date,
    u.channel,
    u.device_os,
    u.app_version,
    u.ab_test_group,
    u.country,
    COALESCE(MAX(CASE WHEN e.event_name = 'app_open' THEN 1 ELSE 0 END), 0) AS step_1_open,
    COALESCE(MAX(CASE WHEN e.event_name = 'signup_initiated' THEN 1 ELSE 0 END), 0) AS step_2_signup_init,
    COALESCE(MAX(CASE WHEN e.event_name = 'signup_completed' THEN 1 ELSE 0 END), 0) AS step_3_signup_done,
    COALESCE(MAX(CASE WHEN e.event_name = 'kyc_initiated' THEN 1 ELSE 0 END), 0) AS step_4_kyc_init,
    COALESCE(MAX(CASE WHEN e.event_name = 'kyc_completed' THEN 1 ELSE 0 END), 0) AS step_5_kyc_done,
    COALESCE(MAX(CASE WHEN e.event_name = 'first_core_action' THEN 1 ELSE 0 END), 0) AS step_6_activated,
    -- Time to complete signup (seconds)
    EXTRACT(EPOCH FROM (
        MIN(CASE WHEN e.event_name = 'signup_completed' THEN e.event_timestamp END) - 
        MIN(CASE WHEN e.event_name = 'app_open' THEN e.event_timestamp END)
    )) AS seconds_to_signup
FROM dim_users u
LEFT JOIN fact_events e ON u.user_id = e.user_id
GROUP BY 
    u.user_id, u.signup_date, u.channel, u.device_os, 
    u.app_version, u.ab_test_group, u.country;


-- ----------------------------------------------------------------------------
-- View 2: vw_ab_test_performance
-- Pre-aggregates A/B experimentation groups for the Executive Variant Scorecard
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_ab_test_performance AS
SELECT 
    u.ab_test_group,
    u.device_os,
    u.channel,
    COUNT(DISTINCT u.user_id) AS total_users,
    COUNT(DISTINCT CASE WHEN e.event_name = 'signup_completed' THEN u.user_id END) AS signups,
    COUNT(DISTINCT CASE WHEN e.event_name = 'kyc_completed' THEN u.user_id END) AS verified_users,
    COUNT(DISTINCT CASE WHEN e.event_name = 'first_core_action' THEN u.user_id END) AS activated_users
FROM dim_users u
LEFT JOIN fact_events e ON u.user_id = e.user_id
GROUP BY u.ab_test_group, u.device_os, u.channel;


-- ----------------------------------------------------------------------------
-- View 3: vw_user_retention_grid
-- Granular cohort tracking table for matrix heatmaps in Power BI
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_user_retention_grid AS
SELECT 
    u.user_id,
    u.signup_date,
    DATE_TRUNC('month', u.signup_date) AS cohort_month,
    u.ab_test_group,
    u.device_os,
    u.channel,
    e.event_timestamp::date AS activity_date,
    (e.event_timestamp::date - u.signup_date) AS day_number
FROM dim_users u
JOIN fact_events e ON u.user_id = e.user_id
WHERE e.event_name IN ('app_open', 'repeat_action')
GROUP BY 
    u.user_id, u.signup_date, cohort_month, 
    u.ab_test_group, u.device_os, u.channel, 
    activity_date, day_number;


-- ----------------------------------------------------------------------------
-- View 4: vw_daily_engagement_kpis
-- Daily active user counts, session frequency, and activity events
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_daily_engagement_kpis AS
SELECT 
    event_timestamp::date AS activity_date,
    COUNT(DISTINCT user_id) AS daily_active_users,
    COUNT(DISTINCT session_id) AS daily_sessions,
    COUNT(event_id) AS total_events_fired,
    COUNT(CASE WHEN event_name = 'first_core_action' THEN 1 END) AS daily_new_activations
FROM fact_events
GROUP BY event_timestamp::date;
