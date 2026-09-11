-- ============================================================================
-- 04_retention_and_stickiness.sql
-- Project: App Product Growth & A/B Experimentation Analytics
-- Purpose: Cohort-based N-Day Retention (D1, D3, D7, D14, D30),
--          DAU / WAU / MAU Stickiness Ratio, and L28 Power-User Curves
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Query 1: Classic Product Retention Cohort Matrix (D1, D3, D7, D14, D30)
-- Measures what percentage of users come back to perform actions after N days
-- ----------------------------------------------------------------------------
WITH user_signup_cohorts AS (
    SELECT 
        user_id,
        signup_date,
        DATE_TRUNC('month', signup_date) AS cohort_month
    FROM dim_users
),
user_activity_days AS (
    SELECT 
        e.user_id,
        c.cohort_month,
        c.signup_date,
        e.event_timestamp::date AS activity_date,
        (e.event_timestamp::date - c.signup_date) AS day_diff
    FROM fact_events e
    JOIN user_signup_cohorts c ON e.user_id = c.user_id
    WHERE e.event_name IN ('app_open', 'repeat_action')
    GROUP BY e.user_id, c.cohort_month, c.signup_date, e.event_timestamp::date
)
SELECT 
    cohort_month,
    COUNT(DISTINCT c.user_id) AS cohort_size,
    -- Day 1 Retention %
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN a.day_diff = 1 THEN a.user_id END) / 
          COUNT(DISTINCT c.user_id), 2) AS d1_retention_pct,
    -- Day 3 Retention %
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN a.day_diff = 3 THEN a.user_id END) / 
          COUNT(DISTINCT c.user_id), 2) AS d3_retention_pct,
    -- Day 7 Retention % (Industry Standard Milestone)
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN a.day_diff = 7 THEN a.user_id END) / 
          COUNT(DISTINCT c.user_id), 2) AS d7_retention_pct,
    -- Day 14 Retention %
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN a.day_diff = 14 THEN a.user_id END) / 
          COUNT(DISTINCT c.user_id), 2) AS d14_retention_pct,
    -- Day 30 Retention %
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN a.day_diff = 30 THEN a.user_id END) / 
          COUNT(DISTINCT c.user_id), 2) AS d30_retention_pct
FROM user_signup_cohorts c
LEFT JOIN user_activity_days a ON c.user_id = a.user_id
GROUP BY cohort_month
ORDER BY cohort_month;


-- ----------------------------------------------------------------------------
-- Query 2: Daily Product Stickiness Engine (DAU, WAU, MAU, & DAU/MAU Ratio)
-- Uses window aggregation over a calendar date spine
-- ----------------------------------------------------------------------------
WITH calendar_dates AS (
    SELECT DISTINCT event_timestamp::date AS activity_date
    FROM fact_events
    WHERE event_timestamp >= '2026-06-30' -- Warm-up period for 30-day rolling window
),
daily_active AS (
    SELECT 
        event_timestamp::date AS activity_date,
        COUNT(DISTINCT user_id) AS dau
    FROM fact_events
    GROUP BY event_timestamp::date
)
SELECT 
    c.activity_date,
    COALESCE(d.dau, 0) AS dau,
    -- 7-Day Rolling Unique Active Users (WAU)
    (
        SELECT COUNT(DISTINCT user_id)
        FROM fact_events
        WHERE event_timestamp::date BETWEEN c.activity_date - INTERVAL '6 days' AND c.activity_date
    ) AS wau,
    -- 30-Day Rolling Unique Active Users (MAU)
    (
        SELECT COUNT(DISTINCT user_id)
        FROM fact_events
        WHERE event_timestamp::date BETWEEN c.activity_date - INTERVAL '29 days' AND c.activity_date
    ) AS mau
FROM calendar_dates c
LEFT JOIN daily_active d ON c.activity_date = d.activity_date
ORDER BY c.activity_date DESC;


-- ----------------------------------------------------------------------------
-- Query 3: The L28 Power-User Curve
-- Analyzes user engagement depth: How many distinct days did active users return
-- out of the past 28-day evaluation window?
-- Separates casual users (1-3 days) from power users (20+ days).
-- ----------------------------------------------------------------------------
WITH reference_window AS (
    SELECT MAX(event_timestamp::date) AS max_date
    FROM fact_events
),
user_active_days_28 AS (
    SELECT 
        e.user_id,
        COUNT(DISTINCT e.event_timestamp::date) AS days_active_in_l28
    FROM fact_events e
    CROSS JOIN reference_window r
    WHERE e.event_timestamp::date BETWEEN (r.max_date - INTERVAL '27 days') AND r.max_date
    GROUP BY e.user_id
)
SELECT 
    days_active_in_l28,
    COUNT(user_id) AS user_count,
    ROUND(100.0 * COUNT(user_id) / SUM(COUNT(user_id)) OVER(), 2) AS user_distribution_pct,
    CASE 
        WHEN days_active_in_l28 BETWEEN 1 AND 3 THEN 'Casual (1-3 days)'
        WHEN days_active_in_l28 BETWEEN 4 AND 10 THEN 'Core Active (4-10 days)'
        WHEN days_active_in_l28 BETWEEN 11 AND 20 THEN 'High Engagement (11-20 days)'
        ELSE 'Power User (21-28 days)'
    END AS engagement_tier
FROM user_active_days_28
GROUP BY days_active_in_l28
ORDER BY days_active_in_l28;
