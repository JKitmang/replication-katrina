# Data Cleaning Process & Key Analytical Decisions

*Companion to the main [README](../README.md) for the replication package of
**"Katrina's Children: Evidence on the Structure of Peer Effects from Hurricane
Evacuees"** (Imberman, Kugler & Sacerdote).*

This document narrates **how the raw administrative records become the estimation
datasets**, and—just as importantly—**the judgment calls** the authors made along
the way and the reasons they give for each. Where a decision is implemented in
code, the relevant file is named so you can read the exact lines (now commented).

---

## 0. The two data systems at a glance

| | **Houston (HISD)** | **Louisiana (statewide)** |
|---|---|---|
| Raw inputs | per-year Access/SQL dumps: attendance/ADA, demographics, TAKS (and legacy Stanford/Aprenda/TAAS), discipline, student–teacher links | LEAP/iLEAP/GEE test files (`LA_leap00_09.dta`) + a prepped student panel (`la_prepped_revisionFULL_SAMPLE.dta`) |
| Cleaning files | `attendence.do`, `demographics_clean.do`, `taks_append.do`, `discipline.do` → `merge_c.do` | `alt_scale.do`, `alt_standardize.do`, `alt_standardize_2.do`, `school_level_means.do` |
| Final analysis files | `katrina_data_with_evacs.dta` (incumbents + evacuees), `katrina_data.dta` (incumbents only) | `alternative_standardization.dta` merged inside the analysis files |
| Unit | student-year (also school-year and classroom-year) | student-year (also school-year) |

---

## 1. Houston cleaning pipeline (in run order)

### 1.1 `attendence.do` — enrollment, attendance, and the evacuee flag
* Appends **per-year** ADA ("average daily attendance") extracts from 1993-94
  through 2006-07, loaded via `odbc load`.
* **Key decisions:**
  * **Attendance rate fallback** — where the supplied `perc_attn` is missing, it
    is recomputed as `100 × days_present / days_enrolled`.
  * **Pre-1995 fields dropped** — enter/leave dates, status, and ZIP are unreliable
    before 1995-96 and are set to missing for those years.
  * **De-duplication** — a handful of student-year rows with conflicting entry
    dates or ZIPs are collapsed (drop the row with the missing ZIP; blank the
    entry date where it conflicts). Specific one-off IDs are hand-fixed.
  * **The evacuee variable is born here.** HISD recorded a *location code* for
    Katrina/Rita students **only in 2005-06**. The code creates
    `katrina = (location code is non-missing)`, then **carries the 2005 value
    forward to 2006** (`replace katrina = l.katrina if year==2006`), and sets it
    **missing before 2005** (it becomes 0 later in `merge_c.do`). This is the
    pivotal definition the whole paper rests on, and the reason the analysis
    sample is restricted to students enrolled in 2005-06 (status is otherwise
    unobserved).
  * `katrina_timeinhisd` measures how long an evacuee stayed in HISD during 2005
    (with `9999` = stayed all year).

### 1.2 `demographics_clean.do` — student characteristics
* Appends demographic files 1993–2006 and **reconciles inconsistent variable
  names across years** (e.g. `camp`/`campus`/`campus_int` → `campus`;
  `ethnicit`/`ethnic` → `ethnicity`; `dob6`/`dob_6` → `dob`; gender strings →
  numeric `female`).
* **Key decisions:**
  * **Economic-disadvantage decoding** — the single `econ` code is split into
    `freelunch` (==1), `redlunch` (==2), `othecon` (==99).
  * **Grade coding** — letters mapped to numbers: `KG`→0, `PK`→−1, `EE`→−2; rows
    with no grade are dropped.
  * **Title-1 dropped** — the supplied flag is judged faulty and removed (to be
    matched by school later if needed).
  * A couple of contradictory program flags (ESL/bilingual without LEP) are dropped.

### 1.3 `taks_append.do` — assembling the test scores
* Appends every TAKS file (2002–2006), across **English and Spanish** versions and
  the multiple within-year administration subsets.
* **Key decisions:**
  * **Bad scores blanked** — if "met minimum standard" is `?`/missing/99, the raw
    and scale scores are set missing (treated as invalid).
  * **Long → wide by subject** via `reshape`, after building a sequence id.
  * **Multiple scores in a subject-year (retakes):** the file keeps **two**
    measures — the **minimum** and the **mean** of the multiple scores — and
    flags the student (`flag_taks_multtest`). The authors deliberately **use the
    minimum** downstream, reasoning that retakers are mostly students who first
    failed and were then coached, so the later/higher score overstates ability;
    the first/min score is the more accurate measure of underlying achievement.
  * **Test version coded** 1 = English, 2 = Spanish, 3 = took both.
  * **Conflicting campuses** for one subject-year are blanked and flagged.

### 1.4 `discipline.do` — infraction counts
* Builds counts of disciplinary infractions (those resulting in **in-school
  suspension or more severe**), plus sub-categories (violations, substance,
  crime, suspensions in/out, expulsion, AEP referral, fighting).
* **Key decision:** a **missing** discipline record means **no infractions**, so
  these are recoded to `0` (done in `merge_c.do` after the merge).

### 1.5 `merge_c.do` — the master merge (the analytic core)
This is where the Houston estimation dataset is actually constructed. In order:

1. **Merge** attendance ⨝ demographics ⨝ Stanford ⨝ Aprenda ⨝ TAAS ⨝ TAKS ⨝
   discipline ⨝ student–teacher links into `hisd_data.dta`.
2. **Score standardization (TAKS).** Convert TAKS scale scores to SD units
   **within grade × year**, using **state-published statewide means and SDs**
   that are **hardcoded** for grades 3–11, years 2002–2008 (e.g.
   `(taks_scale_min_read − 2254.6)/183.45 if grade==3 & year==2002`). An
   *alternative* standardization using only **2003-04 (pre-Katrina)** scale
   moments is also built (`taks_sdalt_*`). *(For legacy Stanford/Aprenda scores,
   standardization is done data-drivenly within grade×year, excluding evacuees.)*
   → See *Decision: standardize on statewide vs. own-sample moments* below.
3. **Missing-value conventions** — discipline → 0; impute **time-invariant**
   demographics (`female`, `ethnicity`, `dob`) forward/backward within student and
   **flag** every imputed cell; impute **grade** by assuming normal grade
   progression from the nearest observed grade (cap at 12; drop if < −2).
4. **Sample frame for the regressions:**
   * keep only students with a grade (i.e. enrolled in late October) and
     non-missing attendance;
   * `keep if year >= 2002`;
   * **restrict to students enrolled in 2005-06** (`enroll_0506`), because evacuee
     status is only observed then;
   * drop pre-grade-1 students; blank grade-12 test scores (all retakers).
5. **Evacuee shares (the treatment).** `katrina = 0` before 2005, then the share
   of evacuees is built at three levels:
   * **campus** (`katrina_frac_campus`),
   * **grade** (`katrina_frac_grade`), and
   * **class** (`katrina_frac_class`, grades 1–5 only, using teacher links),
   plus **by-gender** and **by-race** interacted shares, and **by-quartile**
   shares (evacuees split by their TAKS quartile). For 2006 the evacuee-quartile
   share is **carried forward from 2005** (status fixed at arrival).
6. **The instrument.** Merge in school-level Katrina enrollment counts and the
   **shelter** rosters dated **September 13 / 29 / October 28, 2005**. The
   instrument is the **Sept-13-2005 evacuee share**, computed as
   `katrina_enroll_9_13_05 / enroll_9_13_05`, with two deliberate adjustments:
   * **Subtract the mega-shelter residents** (Astrodome, Reliant, George R. Brown)
     from the 9/13 count — these students almost all moved to other schools within
     two weeks, so excluding them makes the initial-placement instrument more
     accurate (`katrina_enroll_noRGB_9_13_05`).
   * Because total 9/13 enrollment is unobserved, estimate it as
     `enroll_campus_05 − katrina_enroll_10_31_05 + katrina_enroll_9_13_05`.
   All instrument variables are **0 for years < 2005** and for schools not on
   HISD's evacuee list (assumed to have taken in no evacuees).
7. **Maximum-grade correction.** Some elementary schools have a few 6th-graders;
   some high schools have grade gluts from stricter promotion. The authors define
   each school's true top grade `maxgrade2` by **visual inspection of enrollment
   counts** (a long block of hand-coded `if campus==… & grade…` rules) — used to
   identify students who "age out" of a school vs. switch. This is one of the more
   manual, school-specific cleaning steps in the package.
8. **Save** `katrina_data_with_evacs.dta` (incumbents + evacuees) and, after
   `drop if katrina==1`, `katrina_data.dta` (incumbents only — the main
   estimation file).

### 1.6 `quartile_data.do`, `quintile_data.do`, `placebo_quartile_data.do`
* Sort incumbents into **pre-Katrina achievement quartiles** using each student's
  **2003-04** TAKS score, falling back to **2002-03** if 2003-04 is missing
  (`quantiles … nq(4) stable`).
* **Key decision — thin cells blanked:** quartiles are set missing for grade/year
  cells without a critical mass of pre-period scores (e.g. grade 3 in 2005/2006,
  grade 4 in 2006), so students are never assigned to a quartile estimated off too
  few peers.
* `quintile_data.do` is the 5-group version (Appendix Table 6);
  `placebo_quartile_data.do` builds the quartiles used in the falsification test
  that assigns 2005-06 shares to 2004-05.

---

## 2. Louisiana cleaning pipeline

### 2.1 `alt_scale.do` — collapse raw scale scores
* From `LA_leap00_09.dta`: map `grade=="HS"` to 10, coalesce the various
  scale-score fields, set 0s to missing, and `collapse (min)` to one score per
  student-year-subject. **The `(min)` again implements the "use the lowest score
  among retakes" decision.**

### 2.2 `alt_standardize.do` — standardize within grade × year
* Builds `la_means.dta` = mean and SD of math/ELA scale scores **by grade × year**,
  computed over a **restricted standardizing sample** (see decision below), then
  standardizes everyone against those moments (`(score − mean)/sd`).
* **Lags** are constructed as the student's **most recent prior** standardized
  score, with year/grade of the lag retained; a `math0005`/`ela0005` "best
  pre-2006 score" is also built for sorting.
* **Year range hardcoded** `forvalues year = 2000/2007` — extend for new years.

### 2.3 `alt_standardize_2.do` — non-evacuee-only standardization
* Identical idea, but the standardizing moments are computed using **only students
  who were never evacuees, in non-Katrina districts, with school evacuee share
  < 70%** (`everkatrina==0 & katrina_district2==0 & percent_katrina<.7`). This
  produces Appendix Table 38's alternative standardization and is the cleaner
  choice when one worries that including evacuees in the normalization mechanically
  moves the grade-year mean.

### 2.4 `school_level_means.do`
* Collapses to **school-level** means of performance and evacuee shares, feeding
  the school-level placebo and pre-trend tests (Table 9; App. Tables 25–26).

---

## 3. The cross-cutting key decisions (and why)

These recur across many files; understanding them is the fastest way to read the
whole package.

### Decision 1 — Who is an "evacuee," and the 2005-06 anchor
Evacuee status is observed **only in 2005-06** (Houston records a location code;
Louisiana identifies new arrivals from the affected parishes). Consequences baked
into the code everywhere:
* `katrina = 0` for all years **before 2005**;
* 2006 evacuee status/quartile is **carried forward from 2005**;
* the **estimation sample is conditioned on being enrolled in 2005-06**.
Rita evacuees are folded into the "Katrina" group (`replace katrina_sum=1 if rita==1`).

### Decision 2 — Excluded geographies and evacuee-only schools
Schools in the **directly hit parishes/districts** are dropped (Orleans,
Jefferson, St. Bernard, Plaquemines for Katrina; Cameron, Calcasieu for Rita —
`katrina_district2`/`cameron_calcasieu` in `alt_standardize.do`). **Schools with
> 70% evacuees** are also dropped (effectively evacuee-only schools), so the
estimates describe incumbents in ordinary receiving schools.

### Decision 3 — Test-score standardization
Scores are expressed in **SD units within grade × year** so coefficients are
comparable across grades and tests. Two sub-decisions:
* **Statewide vs. own-sample moments.** Houston TAKS uses **state-published**
  grade×year means/SDs **hardcoded** in `merge_c.do` (so the metric does not
  depend on the estimation sample); Louisiana computes moments **from the data**
  (`alt_standardize*.do`). `alt_standardize_2.do` and the `*_statestd` /
  `*_altstd` / `*_scale` analysis variants exist precisely to show results are
  robust to *how* scores are standardized (App. Tables 29, 38).
* **Lowest score among retakes.** Both systems take the **minimum** score when a
  student has multiple scores in a subject-year, on the logic that retakes follow
  failure + coaching and overstate true achievement.

### Decision 4 — Level of the peer measure (campus / grade / class)
The treatment—**evacuee share**—is built at **school**, **grade**, and (Houston
grades 1–5 only) **classroom** level. The working paper headlines the
**school-level** share (LA has few tested grades pre-2005, and middle/high mix
across grades); the published version emphasizes the **grade-level** share; the
**classroom** share enables the Houston "bad apple" tests. Many analysis files are
simply the same regression at a different aggregation level
(`…_va` vs `…_va_grade` vs `…_va_class` vs `…_va_campusgrade` vs `…_va_campusyear`).

### Decision 5 — The September-13-2005 instrument
Because evacuees re-sorted across schools through the fall, the late-October share
is endogenous. The **initial (Sept-13-2005) share** is used as an instrument, with
the **mega-shelter residents subtracted** (they moved within ~2 weeks). This is
the cleanest within-package illustration of the identification strategy and lives
entirely in `merge_c.do` and the `katrina_iv_*` files.

### Decision 6 — Baseline-achievement quartiles and thin cells
Incumbents (and, in LA, evacuees) are sorted into **pre-Katrina** quartiles to
study the *structure* of peer effects. Two guards: (a) sort on a **pre-period**
score so the quartile is predetermined relative to treatment; (b) **blank
quartiles for grade/year cells with too few baseline scores**, so no student is
assigned off a thin distribution. The 4×4 incumbent-quartile × evacuee-quartile
interaction is the object of Tables 4–5 and most appendix robustness.

### Decision 7 — Imputation, and being explicit about it
Time-invariant traits (gender, ethnicity, DOB) and **grade** are imputed from a
student's other years, but **every imputed cell is flagged** (`flag_*_impute`), so
analyses can be re-run excluding imputations. Missing discipline is treated as
zero infractions.

### Decision 8 — Lagged achievement controls
The published specification controls for **lagged pre-Katrina achievement**,
constructed as the most recent *pre-2006* score and (in the main spec)
**interacted with the number of years between exams** and with quartiles. The
`_nolag` files drop the lag; the `_nolagint` files keep the lag but do not
interact it — these generate the robustness rows showing the result is not an
artifact of the lag specification.

---

## 4. Practical reading order

To understand the package end-to-end, read the (now-commented) files in this
order:

1. `attendence.do` → `demographics_clean.do` → `taks_append.do` → `discipline.do`
   (how each Houston domain is cleaned),
2. **`merge_c.do`** (how they combine into the treatment, instrument, and
   quartiles — the single most important file),
3. `quartile_data.do` (baseline quartiles),
4. `alt_standardize.do` (the Louisiana analogue of steps 2–3),
5. one analysis file per design — `katrina_by_quartiles_va_grade_statestd.do`
   (OLS DiD), `katrina_iv_gender_ethnicity_noshelter_grade.do` (2SLS),
   `quartile_analysis_revision_d.do` (the LA quartile workhorse), and
   `epple_romano_f_math_grade_fullintb.do` (linear-in-means).

For the reusable code idioms those analysis files share, see
[`PROGRAMS_AND_COMMANDS.md`](PROGRAMS_AND_COMMANDS.md).
