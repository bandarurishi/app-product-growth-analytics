# Product Analyst CV Bullets & Interview Preparation Toolkit
**Project:** Mobile & Web App Product Growth Analytics & A/B Experimentation Suite  

---

## 1. Resume / CV Ready Bullet Points

Use these bullet points in your CV under the **Projects** or **Work Experience** section. They are pre-formatted using Google's **XYZ Framework** (*Accomplished [X], as measured by [Y], by doing [Z]*):

### Option A: High-Impact Recruiter-Hook Format (~133 characters each)
- Uncovered a 26% Android onboarding leak across 46K+ events using SQL CTEs; proposed camera SDK fixes saving $42K in monthly revenue.
- Designed an A/B test statistical engine (Z=11.45, p<0.001) proving Variant B drove an 11% signup lift without diluting user activation.
- Identified core product habituation by modeling L28 power-user curves and D1-D30 retention cohorts in SQL to isolate sticky segments.
- Architected a 3-page Power BI executive suite via Star Schema and DAX, empowering PMs to drill into real-time DAU/MAU app stickiness.

### Option B: Condensed 2-Bullet Format (For tight 1-page CVs)
> **App Product Growth & A/B Experimentation Analytics** | *SQL, Power BI, DAX*
> - Analyzed 46k+ clickstream event logs using advanced SQL (CTEs, Window Functions) to diagnose onboarding funnel friction, discovering a 26% KYC drop-off gap between Android and iOS users.
> - Designed an A/B experimentation scorecard and DAU/MAU stickiness dashboard in Power BI, validating an 11% conversion lift ($p < 0.001$) and establishing automated D1–D30 cohort retention tracking.

---

## 2. Top 5 Product Analyst Interview Questions & How to Answer Them

### Q1: "Walk me through this project."
**How to answer (The 90-Second Pitch):**
> *"In this project, I acted as the Product Analyst for a consumer app undergoing a major onboarding redesign. The problem was that while top-of-funnel acquisition was high, product activation was stalling, and leadership wanted to know whether our new onboarding flow (Variant B) was truly outperforming the legacy flow.
> 
> I built an end-to-end data pipeline: First, I modeled 46,000+ granular clickstream events in SQL to map out our 6-stage funnel. This revealed that while iOS had an 88% KYC completion rate, Android was bottlenecked at 61% due to camera upload latency. 
> 
> Second, I built a statistical hypothesis testing model directly in SQL, proving that Variant B delivered an 11% absolute lift in signup completion with high statistical significance ($p < 0.001$), while confirming downstream activation remained intact. 
> 
> Finally, I connected this to a 3-page Power BI dashboard tracking DAU/MAU stickiness and D1-to-D30 cohort retention for our Product Managers."*

---

### Q2: "Our onboarding conversion dropped by 10% this week. How would you diagnose it?"
**How to answer (The Diagnostic Framework):**
> 1. **Data Integrity & Tracking Check**: First, verify if the drop is real or a tracking glitch (e.g., did an app release break the event trigger tag?).
> 2. **Isolate the Funnel Step**: Break the funnel into individual conversion transitions (Step 1 $\rightarrow$ 2, Step 2 $\rightarrow$ 3, etc.) to see which exact step absorbed the drop.
> 3. **Segment by Dimensions**: Slice the offending step by:
>    - **Platform / OS**: Did an Android or iOS OS update introduce bugs?
>    - **App Version**: Did a recent build introduce UI latency or crashes?
>    - **Acquisition Channel**: Did a marketing campaign flood the app with low-intent bots/leads?
>    - **Geography / Network**: Are users in specific regions failing due to payment gateway timeouts?
> 4. **Synthesize & Collaborate**: Formulate a hypothesis and share findings with PMs and engineering for a hotfix.

---

### Q3: "How did you evaluate statistical significance for your A/B test?"
**How to answer:**
> *"Because signup completion is a binomial proportion (a user either completes signup or doesn't), I formulated a two-proportion Z-test.
> - $H_0$: Conversion rate of Control = Conversion rate of Variant.
> - $H_1$: Conversion rate of Control $\neq$ Conversion rate of Variant.
> 
> I calculated the pooled sample proportion, derived the standard error based on sample sizes ($N_A \approx 5,000$, $N_B \approx 5,000$), and computed the Z-score. Since our Z-score exceeded $1.96$, we rejected the null hypothesis at the 95% confidence interval ($p < 0.001$).
> Crucially, I also ran guardrail checks on downstream metrics (First Core Action and D7 Retention) to ensure that the easier signup flow didn't just bring in unqualified churn-prone users."*

---

### Q4: "What is the difference between Product Retention and Product Stickiness?"
**How to answer:**
> *"They measure two different dimensions of engagement:
> - **Retention (e.g., D7, D30)** measures **longevity**: Out of users who joined on Day 0, what percentage return on Day $N$? It tells us if users find enduring value over time.
> - **Stickiness ($\text{DAU} / \text{MAU}$)** measures **frequency and habituation**: Out of all users active this month, what fraction use the product on any given day? A ratio of 20% means an average user opens the app 6 days a month, which indicates strong daily habit formation."*

---

### Q5: "How did you decide what to compute in SQL vs. DAX in Power BI?"
**How to answer (Architectural Best Practice):**
> *"I followed the fundamental BI principle of **pushing compute upstream**:
> - **Heavy transformations & row-level event parsing** (sessionization, funnel milestone flags, timestamp deltas, raw Z-score formulas) were executed in **SQL views**. This minimized the data volume imported into Power BI and kept refresh times fast.
> - **Dynamic slicing, time-intelligence, and user interactions** (DAU/MAU date ranges, dynamic conversion rate slicers by channel/OS, and interactive What-If parameters) were written in **DAX**, allowing end-users to filter seamlessly across dimensions."*
