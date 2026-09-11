-- ============================================================================
-- 02_funnel_dropoff_analysis.sql
-- Project: App Product Growth & A/B Experimentation Analytics
-- Purpose: User Onboarding Funnel Conversion, Stage-by-Stage Drop-off,
--          Device/Channel Friction Diagnosis, and Time-to-Convert Metrics
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Query 1: Master 6-Stage User Onboarding Funnel
-- Calculates overall users reaching each stage, step-to-step drop-off rate %,
-- and overall cumulative conversion from top of funnel.
-- ----------------------------------------------------------------------------
WITH user_milestones AS (
    SELECT 
        u.user_id,
        u.ab_test_group,
        u.device_os,
        u.channel,
        MAX(CASE WHEN e.event_name = 'app_open' THEN 1 ELSE 0 END) AS s1_app_open,
        MAX(CASE WHEN e.event_name = 'signup_initiated' THEN 1 ELSE 0 END) AS s2_signup_initiated,
        MAX(CASE WHEN e.event_name = 'signup_completed' THEN 1 ELSE 0 END) AS s3_signup_completed,
        MAX(CASE WHEN e.event_name = 'kyc_initiated' THEN 1 ELSE 0 END) AS s4_kyc_initiated,
        MAX(CASE WHEN e.event_name = 'kyc_completed' THEN 1 ELSE 0 END) AS s5_kyc_completed,
        MAX(CASE WHEN e.event_name = 'first_core_action' THEN 1 ELSE 0 END) AS s6_activated
    FROM dim_users u
    LEFT JOIN fact_events e ON u.user_id = e.user_id
    GROUP BY u.user_id, u.ab_test_group, u.device_os, u.channel
),
funnel_aggregates AS (
    SELECT 
        COUNT(user_id) AS total_top_funnel,
        SUM(s1_app_open) AS step1_open,
        SUM(s2_signup_initiated) AS step2_initiated,
        SUM(s3_signup_completed) AS step3_signed_up,
        SUM(s4_kyc_initiated) AS step4_kyc_started,
        SUM(s5_kyc_completed) AS step5_kyc_done,
        SUM(s6_activated) AS step6_activated
    FROM user_milestones
)
SELECT 
    'Step 1: App Open' AS funnel_stage,
    step1_open AS total_users,
    100.0 AS step_to_step_conversion_pct,
    0.0 AS drop_off_pct,
    100.0 AS cumulative_conversion_pct
FROM funnel_aggregates

UNION ALL

SELECT 
    'Step 2: Signup Initiated',
    step2_initiated,
    ROUND(100.0 * step2_initiated / NULLIF(step1_open, 0), 2),
    ROUND(100.0 * (step1_open - step2_initiated) / NULLIF(step1_open, 0), 2),
    ROUND(100.0 * step2_initiated / NULLIF(step1_open, 0), 2)
FROM funnel_aggregates

UNION ALL

SELECT 
    'Step 3: Signup Completed',
    step3_signed_up,
    ROUND(100.0 * step3_signed_up / NULLIF(step2_initiated, 0), 2),
    ROUND(100.0 * (step2_initiated - step3_signed_up) / NULLIF(step2_initiated, 0), 2),
    ROUND(100.0 * step3_signed_up / NULLIF(step1_open, 0), 2)
FROM funnel_aggregates

UNION ALL

SELECT 
    'Step 4: KYC Initiated',
    step4_kyc_started,
    ROUND(100.0 * step4_kyc_started / NULLIF(step3_signed_up, 0), 2),
    ROUND(100.0 * (step3_signed_up - step4_kyc_started) / NULLIF(step3_signed_up, 0), 2),
    ROUND(100.0 * step4_kyc_started / NULLIF(step1_open, 0), 2)
FROM funnel_aggregates

UNION ALL

SELECT 
    'Step 5: KYC Completed',
    step5_kyc_done,
    ROUND(100.0 * step5_kyc_done / NULLIF(step4_kyc_started, 0), 2),
    ROUND(100.0 * (step4_kyc_started - step5_kyc_done) / NULLIF(step4_kyc_started, 0), 2),
    ROUND(100.0 * step5_kyc_done / NULLIF(step1_open, 0), 2)
FROM funnel_aggregates

UNION ALL

SELECT 
    'Step 6: First Core Action (Activated)',
    step6_activated,
    ROUND(100.0 * step6_activated / NULLIF(step5_kyc_done, 0), 2),
    ROUND(100.0 * (step5_kyc_done - step6_activated) / NULLIF(step5_kyc_done, 0), 2),
    ROUND(100.0 * step6_activated / NULLIF(step1_open, 0), 2)
FROM funnel_aggregates;


-- ----------------------------------------------------------------------------
-- Query 2: Funnel Friction Diagnostics Sliced by Device OS
-- Pinpoints where each platform encounters drop-offs (reveals Android KYC friction)
-- ----------------------------------------------------------------------------
WITH device_funnel AS (
    SELECT 
        u.device_os,
        COUNT(DISTINCT u.user_id) AS total_users,
        COUNT(DISTINCT CASE WHEN e.event_name = 'signup_completed' THEN u.user_id END) AS completed_signup,
        COUNT(DISTINCT CASE WHEN e.event_name = 'kyc_initiated' THEN u.user_id END) AS initiated_kyc,
        COUNT(DISTINCT CASE WHEN e.event_name = 'kyc_completed' THEN u.user_id END) AS completed_kyc,
        COUNT(DISTINCT CASE WHEN e.event_name = 'first_core_action' THEN u.user_id END) AS activated_users
    FROM dim_users u
    LEFT JOIN fact_events e ON u.user_id = e.user_id
    GROUP BY u.device_os
)
SELECT 
    device_os,
    total_users,
    completed_signup,
    initiated_kyc,
    completed_kyc,
    activated_users,
    -- Critical Diagnostic: KYC Completion Rate once initiated
    ROUND(100.0 * completed_kyc / NULLIF(initiated_kyc, 0), 2) AS kyc_completion_rate_pct,
    -- Overall End-to-End Activation Rate
    ROUND(100.0 * activated_users / NULLIF(total_users, 0), 2) AS overall_activation_rate_pct
FROM device_funnel
ORDER BY overall_activation_rate_pct DESC;


-- ----------------------------------------------------------------------------
-- Query 3: Funnel Quality by Acquisition Channel
-- Evaluates which marketing channels deliver high intent vs. bouncing users
-- ----------------------------------------------------------------------------
SELECT 
    u.channel,
    COUNT(DISTINCT u.user_id) AS total_installs,
    COUNT(DISTINCT CASE WHEN e.event_name = 'signup_completed' THEN u.user_id END) AS signups,
    COUNT(DISTINCT CASE WHEN e.event_name = 'first_core_action' THEN u.user_id END) AS activated,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN e.event_name = 'signup_completed' THEN u.user_id END) / COUNT(DISTINCT u.user_id), 2) AS signup_conversion_pct,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN e.event_name = 'first_core_action' THEN u.user_id END) / COUNT(DISTINCT u.user_id), 2) AS end_to_end_activation_pct
FROM dim_users u
LEFT JOIN fact_events e ON u.user_id = e.user_id
GROUP BY u.channel
ORDER BY end_to_end_activation_pct DESC;


-- ----------------------------------------------------------------------------
-- Query 4: Time-to-Convert / Onboarding Velocity
-- Measures median and average seconds spent progressing between funnel milestones
-- ----------------------------------------------------------------------------
WITH user_event_timestamps AS (
    SELECT 
        user_id,
        MIN(CASE WHEN event_name = 'app_open' THEN event_timestamp END) AS t_open,
        MIN(CASE WHEN event_name = 'signup_completed' THEN event_timestamp END) AS t_signup,
        MIN(CASE WHEN event_name = 'kyc_completed' THEN event_timestamp END) AS t_kyc,
        MIN(CASE WHEN event_name = 'first_core_action' THEN event_timestamp END) AS t_activation
    FROM fact_events
    GROUP BY user_id
)
SELECT 
    COUNT(user_id) AS activated_users_sample,
    -- Time from open to signup completion (in seconds)
    ROUND(AVG(EXTRACT(EPOCH FROM (t_signup - t_open))), 1) AS avg_sec_to_signup,
    -- Time from signup to KYC completion
    ROUND(AVG(EXTRACT(EPOCH FROM (t_kyc - t_signup))), 1) AS avg_sec_signup_to_kyc,
    -- Total onboarding duration to first core action
    ROUND(AVG(EXTRACT(EPOCH FROM (t_activation - t_open)) / 60.0), 2) AS avg_minutes_to_activate
FROM user_event_timestamps
WHERE t_activation IS NOT NULL;
