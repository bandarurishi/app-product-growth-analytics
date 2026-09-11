# Power BI Data Modeling & DAX Engineering Guide
**Project:** App Product Growth & A/B Experimentation Analytics  
**Target Roles:** Product Analyst, Product Data Scientist, Growth BI Engineer  

---

## 1. Data Model Architecture (Star Schema)

In production Product Analytics, never dump a flat table into Power BI. Model your tables into a clean **Star Schema**:

```
                       ┌─────────────────────────┐
                       │        Dim_Date         │
                       │   (Calendar Date Table) │
                       └────────────┬────────────┘
                                    │ 1
                                    │
                                    │ * (Active Relationship)
 ┌─────────────────────────┐        ▼        ┌─────────────────────────┐
 │        Dim_Users        │*              1 │      Dim_Channels       │
 │   (User Demographics &  ├────────┬───────┤   (Acquisition Channels │
 │      A/B Test Group)    │        │       │       & Platforms)      │
 └───────────┬─────────────┘        │       └─────────────────────────┘
             │ 1                    │
             │                      │
             │ *                    │
             ▼                      ▼
 ┌───────────────────────────────────────────────────┐
 │                    Fact_Events                    │
 │       (Event Logs: 46k+ clickstream records)      │
 └───────────────────────────────────────────────────┘
```

### Table Relationships:
1. `Dim_Users[user_id]` **(1)** $\longrightarrow$ **(\*)** `Fact_Events[user_id]` (Single direction filter)
2. `Dim_Date[Date]` **(1)** $\longrightarrow$ **(\*)** `Dim_Users[signup_date]` (Active)
3. `Dim_Date[Date]` **(1)** $\longrightarrow$ **(\*)** `Fact_Events[event_timestamp]` (Inactive, activated via `USERELATIONSHIP` for event-time intelligence)

---

## 2. Power BI Calendar Table (DAX)

Create a dedicated Date Dimension table using DAX:

```dax
Dim_Date = 
VAR MinDate = DATE(2026, 6, 1)
VAR MaxDate = DATE(2026, 9, 30)
RETURN
ADDCOLUMNS(
    CALENDAR(MinDate, MaxDate),
    "Year", YEAR([Date]),
    "YearMonth", FORMAT([Date], "YYYY-MM"),
    "MonthName", FORMAT([Date], "MMM"),
    "MonthNumber", MONTH([Date]),
    "WeekNumber", WEEKNUM([Date]),
    "DayOfWeek", FORMAT([Date], "ddd"),
    "DayOfWeekNumber", WEEKDAY([Date], 2)
)
```

---

## 3. Production DAX Measure Library

Create a dedicated measure table called `_Product_Measures` to store all calculations.

### Group A: Volume & Top-of-Funnel Counts
```dax
Total_Installs = 
DISTINCTCOUNT(Dim_Users[user_id])
```

```dax
Total_Signups_Completed = 
CALCULATE(
    DISTINCTCOUNT(Fact_Events[user_id]),
    Fact_Events[event_name] = "signup_completed"
)
```

```dax
Total_KYC_Completed = 
CALCULATE(
    DISTINCTCOUNT(Fact_Events[user_id]),
    Fact_Events[event_name] = "kyc_completed"
)
```

```dax
Total_Activated_Users = 
CALCULATE(
    DISTINCTCOUNT(Fact_Events[user_id]),
    Fact_Events[event_name] = "first_core_action"
)
```

---

### Group B: Funnel Step-to-Step Conversion & Drop-off %
```dax
Funnel_Step2_Signup_Init_CR = 
VAR Step1 = [Total_Installs]
VAR Step2 = CALCULATE(DISTINCTCOUNT(Fact_Events[user_id]), Fact_Events[event_name] = "signup_initiated")
RETURN DIVIDE(Step2, Step1, 0)
```

```dax
Funnel_Step3_Signup_Complete_CR = 
VAR Step2 = CALCULATE(DISTINCTCOUNT(Fact_Events[user_id]), Fact_Events[event_name] = "signup_initiated")
VAR Step3 = [Total_Signups_Completed]
RETURN DIVIDE(Step3, Step2, 0)
```

```dax
Funnel_Step4_KYC_Start_CR = 
VAR Step3 = [Total_Signups_Completed]
VAR Step4 = CALCULATE(DISTINCTCOUNT(Fact_Events[user_id]), Fact_Events[event_name] = "kyc_initiated")
RETURN DIVIDE(Step4, Step3, 0)
```

```dax
Funnel_Step5_KYC_Complete_CR = 
VAR Step4 = CALCULATE(DISTINCTCOUNT(Fact_Events[user_id]), Fact_Events[event_name] = "kyc_initiated")
VAR Step5 = [Total_KYC_Completed]
RETURN DIVIDE(Step5, Step4, 0)
```

```dax
Overall_Activation_Rate = 
DIVIDE([Total_Activated_Users], [Total_Installs], 0)
```

---

### Group C: A/B Experimentation Engine (Control vs. Variant Lift)
```dax
Control_Signups_CR = 
CALCULATE(
    DIVIDE([Total_Signups_Completed], [Total_Installs], 0),
    Dim_Users[ab_test_group] = "Control_A"
)
```

```dax
Variant_Signups_CR = 
CALCULATE(
    DIVIDE([Total_Signups_Completed], [Total_Installs], 0),
    Dim_Users[ab_test_group] = "Variant_B"
)
```

```dax
AB_Absolute_Lift = 
[Variant_Signups_CR] - [Control_Signups_CR]
```

```dax
AB_Relative_Lift_Pct = 
DIVIDE([AB_Absolute_Lift], [Control_Signups_CR], 0)
```

```dax
AB_Statistical_Significance_Status = 
// Checks if the absolute lift exceeds standard error threshold (|Z| >= 1.96)
VAR N_Control = CALCULATE([Total_Installs], Dim_Users[ab_test_group] = "Control_A")
VAR N_Variant = CALCULATE([Total_Installs], Dim_Users[ab_test_group] = "Variant_B")
VAR Conv_Control = CALCULATE([Total_Signups_Completed], Dim_Users[ab_test_group] = "Control_A")
VAR Conv_Variant = CALCULATE([Total_Signups_Completed], Dim_Users[ab_test_group] = "Variant_B")
VAR P_Pooled = DIVIDE(Conv_Control + Conv_Variant, N_Control + N_Variant, 0)
VAR SE = SQRT(P_Pooled * (1 - P_Pooled) * (DIVIDE(1, N_Control, 0) + DIVIDE(1, N_Variant, 0)))
VAR Z_Score = DIVIDE([AB_Absolute_Lift], SE, 0)
RETURN
IF(ABS(Z_Score) >= 1.96, "Significant (p < 0.05)", "Not Significant")
```

---

### Group D: Active Users & Stickiness (DAU, WAU, MAU)
```dax
DAU = 
CALCULATE(
    DISTINCTCOUNT(Fact_Events[user_id]),
    USERELATIONSHIP(Dim_Date[Date], Fact_Events[event_timestamp])
)
```

```dax
WAU = 
CALCULATE(
    DISTINCTCOUNT(Fact_Events[user_id]),
    DATESINPERIOD(Dim_Date[Date], MAX(Dim_Date[Date]), -7, DAY),
    USERELATIONSHIP(Dim_Date[Date], Fact_Events[event_timestamp])
)
```

```dax
MAU = 
CALCULATE(
    DISTINCTCOUNT(Fact_Events[user_id]),
    DATESINPERIOD(Dim_Date[Date], MAX(Dim_Date[Date]), -30, DAY),
    USERELATIONSHIP(Dim_Date[Date], Fact_Events[event_timestamp])
)
```

```dax
Stickiness_Ratio = 
DIVIDE([DAU], [MAU], 0)
```

```dax
D7_Retention_Rate = 
VAR SignupCohortUsers = [Total_Installs]
VAR ReturnedOnD7 = 
    CALCULATE(
        DISTINCTCOUNT(Fact_Events[user_id]),
        FILTER(
            Fact_Events,
            Fact_Events[event_name] IN {"app_open", "repeat_action"} &&
            INT(Fact_Events[event_timestamp]) - INT(RELATED(Dim_Users[signup_date])) = 7
        )
    )
RETURN DIVIDE(ReturnedOnD7, SignupCohortUsers, 0)
```

---

## 4. 3-Page Dashboard Blueprint

### 📱 Page 1: User Onboarding Funnel & Drop-off Diagnostics
* **Top Ribbon**: 4 KPI Cards (`Total Installs`, `Signups Completed`, `KYC Completed`, `Overall Activation Rate %`).
* **Main Visual (Center)**: Horizontal Funnel Chart showing Step 1 through Step 6 with data labels showing drop-off %.
* **Left Panel**: Slicers for `Device OS (Android / iOS / Web)`, `Acquisition Channel`, and `Signup Date Range`.
* **Bottom Left (Callout Chart)**: Stacked Bar Chart comparing **KYC Completion Rate by Device OS** (clearly showing Android lagging at 62% vs iOS at 88%).
* **Bottom Right**: Table showing Average Time Spent (seconds) per milestone.

### 🧪 Page 2: A/B Experimentation & Variant Scorecard
* **Top Header**: Banner stating Experiment: *"New Friction-Free 2-Step Auth Flow (Variant B) vs Legacy Flow (Control A)"*.
* **Center Metric Cards**:
  - `Control Conversion Rate` (61.5%) vs `Variant Conversion Rate` (72.1%)
  - `Relative Lift %` (+17.2%)
  - `Statistical Significance` (Badge: "Statistically Significant at 95% Confidence (p < 0.001)")
* **Middle Visual**: Bar chart showing conversion by step for Variant B vs Control A.
* **Bottom Guardrail Visual**: Clustered column chart comparing downstream **D7 Retention** and **First Core Action Rate** across variants, confirming that Variant B did not dilute downstream user quality.

### 📈 Page 3: Product Stickiness & L28 Power-User Distribution
* **Top Ribbon**: `DAU`, `WAU`, `MAU`, and `DAU/MAU Stickiness Ratio` (Target > 20%).
* **Main Visual (Top Half)**: Dual-axis Line Chart showing DAU and MAU trends over 90 days.
* **Bottom Left Visual**: **L28 Power-User Curve** (Histogram of days active in the past 28 days: 1 day, 2 days ... 28 days).
* **Bottom Right Visual**: Cohort Retention Matrix (Heatmap) showing D1, D3, D7, D14, D30 retention across weekly signup cohorts.
