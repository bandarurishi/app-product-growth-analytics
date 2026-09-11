-- ============================================================================
-- 03_ab_experimentation_analysis.sql
-- Project: App Product Growth & A/B Experimentation Analytics
-- Purpose: Rigorous A/B Testing Evaluation in SQL
--          Calculates Conversion Rates, Relative Lift %, Pooled Standard Error,
--          Z-Scores, and Statistical Significance (Alpha = 0.05 / 95% Confidence)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Query 1: Full Statistical Hypothesis Test on Primary Funnel Conversion (Signup)
-- Null Hypothesis (H0): Variant B has no effect on signup completion (p_B - p_A = 0)
-- Alternative (H1)    : Variant B improves signup completion (p_B - p_A != 0)
-- ----------------------------------------------------------------------------
WITH ab_conversions AS (
    SELECT 
        u.ab_test_group,
        COUNT(DISTINCT u.user_id) AS sample_size,
        COUNT(DISTINCT CASE WHEN e.event_name = 'signup_completed' THEN u.user_id END) AS conversions
    FROM dim_users u
    LEFT JOIN fact_events e ON u.user_id = e.user_id
    GROUP BY u.ab_test_group
),
ab_metrics AS (
    SELECT 
        MAX(CASE WHEN ab_test_group = 'Control_A' THEN sample_size END) AS n_control,
        MAX(CASE WHEN ab_test_group = 'Control_A' THEN conversions END) AS conv_control,
        MAX(CASE WHEN ab_test_group = 'Variant_B' THEN sample_size END) AS n_variant,
        MAX(CASE WHEN ab_test_group = 'Variant_B' THEN conversions END) AS conv_variant
    FROM ab_conversions
),
statistical_calculations AS (
    SELECT 
        n_control,
        conv_control,
        ROUND(1.0 * conv_control / n_control, 4) AS cr_control,
        n_variant,
        conv_variant,
        ROUND(1.0 * conv_variant / n_variant, 4) AS cr_variant,
        -- Pooled Proportion: (conv_A + conv_B) / (n_A + n_B)
        1.0 * (conv_control + conv_variant) / (n_control + n_variant) AS p_pooled
    FROM ab_metrics
),
z_score_engine AS (
    SELECT 
        n_control,
        conv_control,
        cr_control,
        n_variant,
        conv_variant,
        cr_variant,
        -- Absolute Lift
        ROUND((cr_variant - cr_control) * 100.0, 2) AS absolute_lift_pct_points,
        -- Relative Lift %: ((cr_B - cr_A) / cr_A) * 100
        ROUND(100.0 * (cr_variant - cr_control) / cr_control, 2) AS relative_lift_pct,
        -- Standard Error (SE) = SQRT( p_pooled * (1 - p_pooled) * (1/n_control + 1/n_variant) )
        SQRT(
            p_pooled * (1.0 - p_pooled) * ((1.0 / n_control) + (1.0 / n_variant))
        ) AS standard_error,
        cr_variant - cr_control AS difference
    FROM statistical_calculations
)
SELECT 
    n_control,
    conv_control,
    ROUND(cr_control * 100.0, 2) AS control_conversion_rate_pct,
    n_variant,
    conv_variant,
    ROUND(cr_variant * 100.0, 2) AS variant_conversion_rate_pct,
    absolute_lift_pct_points,
    relative_lift_pct,
    ROUND(standard_error, 5) AS std_error,
    ROUND(difference / NULLIF(standard_error, 0), 3) AS z_score,
    CASE 
        WHEN ABS(difference / NULLIF(standard_error, 0)) >= 1.960 THEN 'Statistically Significant (p < 0.05)'
        ELSE 'Not Significant (Fail to reject H0)'
    END AS decision_at_95_confidence,
    CASE 
        WHEN ABS(difference / NULLIF(standard_error, 0)) >= 2.576 THEN 'Highly Significant (p < 0.01)'
        ELSE 'Not Significant at 99%'
    END AS decision_at_99_confidence
FROM z_score_engine;


-- ----------------------------------------------------------------------------
-- Query 2: Guardrail & Downstream Metric Check
-- A common pitfall in product experiments: a variant boosts initial signup but 
-- harms downstream quality (activation & retention). We test downstream health:
-- ----------------------------------------------------------------------------
SELECT 
    u.ab_test_group,
    COUNT(DISTINCT u.user_id) AS total_users,
    -- Step 3: Signups
    COUNT(DISTINCT CASE WHEN e.event_name = 'signup_completed' THEN u.user_id END) AS signups,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN e.event_name = 'signup_completed' THEN u.user_id END) / COUNT(DISTINCT u.user_id), 2) AS signup_rate_pct,
    -- Step 6: Core Activation (Guardrail Metric)
    COUNT(DISTINCT CASE WHEN e.event_name = 'first_core_action' THEN u.user_id END) AS activated_users,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN e.event_name = 'first_core_action' THEN u.user_id END) / COUNT(DISTINCT u.user_id), 2) AS activation_rate_pct,
    -- Downstream Quality: Activation rate among signed-up users
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN e.event_name = 'first_core_action' THEN u.user_id END) / 
          NULLIF(COUNT(DISTINCT CASE WHEN e.event_name = 'signup_completed' THEN u.user_id END), 0), 2) AS signup_to_activation_efficiency_pct
FROM dim_users u
LEFT JOIN fact_events e ON u.user_id = e.user_id
GROUP BY u.ab_test_group;
