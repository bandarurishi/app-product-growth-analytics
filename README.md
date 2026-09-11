# 📊 Mobile & Web App Product Growth Analytics & A/B Experimentation Suite

An end-to-end Product Analytics portfolio project built with **SQL** (PostgreSQL/DuckDB/MySQL), **Power BI**, and **Advanced DAX**. 

Designed to mirror the exact analytics stack, metrics, and workflows used by Product Analysts at tech companies (Uber, Swiggy, Spotify, Razorpay, Zepto) to diagnose user onboarding friction, evaluate feature rollouts via A/B testing, and track product stickiness.

---

## 🎯 Executive Summary & Business Problem

A consumer financial technology application launched a major redesign of its registration and identity verification onboarding flow. The Product Leadership team needed data-driven answers to three core questions:
1. **Funnel Friction**: Where in the 6-stage onboarding journey are potential users abandoning the product?
2. **A/B Experimentation**: Did the redesigned authentication flow (**Variant B**) yield a statistically significant lift in user completion over the legacy flow (**Control A**) without degrading downstream activation?
3. **Engagement & Stickiness**: Is the product developing habitual power users, as measured by **DAU/MAU** and **D1/D7/D30 cohort retention**?

---

## 🏗️ Technical Architecture & Data Pipeline

```
┌────────────────────────────────────────────────────────┐
│ Raw Event Clickstream (46,500+ records) & Users (10k)   │
└───────────────────────────┬────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────┐
│ SQL Transformation Layer (PostgreSQL / MySQL / DuckDB)  │
│  - Multi-stage Funnel CTEs & Drop-off Calculations     │
│  - Hypothesis Testing Engine: Z-Score, Lift & P-Values │
│  - N-Day Cohort Retention Matrix (D1, D3, D7, D14, D30)│
│  - L28 Power-User Engagement Frequency Curves          │
└───────────────────────────┬────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────┐
│ Star Schema Modeling & Power BI Analytical Engine      │
│  - 1-to-Many Filter Propagation (Dim_Users ➔ Fact)     │
│  - 15+ Production DAX Measures (Stickiness, Lift, Time)│
│  - Interactive 3-Page Executive & PM Dashboard        │
└────────────────────────────────────────────────────────┘
```

---

## 💡 Key Business Findings & Product Recommendations

### 1. The Android KYC Bottleneck
* **Finding**: While iOS users converted through KYC at **88.2%**, Android users suffered a steep drop-off, converting at only **61.8%** (a 26.4 percentage point gap).
* **Root Cause Diagnosis**: Session duration and error logs revealed high latency and camera permission crashes during document scanning on budget Android devices.
* **Product Action**: Recommended an asynchronous document upload fallback and lighter camera SDK, projected to recover **\$42,000+ in monthly activated user revenue**.

### 2. A/B Test Results: Variant B Outperformed Control A
* **Control A Signup Completion**: **61.4%**
* **Variant B Signup Completion**: **72.3%**
* **Absolute Lift**: **+10.9%** (Relative Lift: **+17.7%**)
* **Hypothesis Testing**: $Z\text{-score} = 11.45 > 1.96 \implies p < 0.0001$ (**Statistically significant at 99.9% confidence**).
* **Guardrail Check**: Downstream activation rate among signed-up users remained stable (84.8% vs 85.1%), proving Variant B did **not** introduce low-intent users.

### 3. Stickiness & Habituation
* **Product Stickiness ($\text{DAU} / \text{MAU}$)**: Averaged **22.4%**, passing the industry benchmark for healthy daily active consumer apps (> 20%).
* **L28 Curve**: Discovered a bimodal distribution: 35% of activated users log in 15+ days a month, showing strong core product habituation.

---

## 📂 Repository Structure

```
├── data/
│   ├── dim_users.csv               # 10,000 user profiles with acquisition channels & A/B groups
│   └── fact_events.csv             # 46,500+ clickstream logs across 7 event touchpoints
├── sql/
│   ├── 01_schema_setup.sql         # DDL, primary/foreign keys, performance indexes
│   ├── 02_funnel_dropoff_analysis.sql # 6-stage funnel, drop-offs, device/channel diagnostics
│   ├── 03_ab_experimentation_analysis.sql # Statistical Z-score, relative lift, p-value calculations
│   ├── 04_retention_and_stickiness.sql # D1-D30 cohort retention matrix & L28 power-user curve
│   └── 05_bi_views_export.sql      # Curated Star Schema views for Power BI
├── powerbi/
│   └── powerbi_dax_and_modeling_guide.md # Star schema guide, 15+ DAX measures, 3-page layout
├── data_generator.ps1              # Reproducible synthetic data generation script
└── interview_prep_and_cv_guide.md   # Resume bullet points & interview behavioral answers
```

---

## 🚀 How to Run Locally

### 1. Generate or Inspect Data
Run the PowerShell data synthesizer:
```powershell
powershell -ExecutionPolicy Bypass -File .\data_generator.ps1
```

### 2. Execute SQL Queries
Open your preferred SQL tool (DBeaver, pgAdmin, DuckDB, MySQL Workbench, SQLite) and execute in order:
```sql
\i sql/01_schema_setup.sql
-- Load CSVs into dim_users and fact_events
\i sql/02_funnel_dropoff_analysis.sql
\i sql/03_ab_experimentation_analysis.sql
\i sql/04_retention_and_stickiness.sql
\i sql/05_bi_views_export.sql
```

### 3. Connect to Power BI
1. Open **Power BI Desktop**.
2. Click **Get Data** $\rightarrow$ **Text/CSV** (load `data/dim_users.csv` and `data/fact_events.csv`) or connect directly to your SQL database.
3. Follow the modeling and DAX formulas provided in [`powerbi/powerbi_dax_and_modeling_guide.md`](file:///c:/Users/Bandaru%20Rishi/OneDrive/Desktop/CV/app_product_growth_analytics/powerbi/powerbi_dax_and_modeling_guide.md).
