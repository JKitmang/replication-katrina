# Replication Package — *Katrina's Children: Evidence on the Structure of Peer Effects from Hurricane Evacuees*

**Scott A. Imberman, Adriana D. Kugler, and Bruce I. Sacerdote**
NBER Working Paper No. 15291 · Published in the *American Economic Review*

> This README documents the data, code, and run order needed to reproduce every
> table and figure in the paper, and—because the package's value for ongoing
> research is in *extending* it—a dedicated section on **re-running the analysis
> with additional school years**. It supersedes the authors' original one-page
> `programs/replication-readme.pdf`, which it incorporates and expands.

---

## Contents

1. [Overview of the study](#1-overview-of-the-study)
2. [What is in this package](#2-what-is-in-this-package)
3. [Software and dependencies](#3-software-and-dependencies)
4. [Data access (the data are proprietary)](#4-data-access-the-data-are-proprietary)
5. [Directory and path conventions](#5-directory-and-path-conventions)
6. [How to run the analysis (`master.do`)](#6-how-to-run-the-analysis-masterdo)
7. [The data-cleaning pipeline](#7-the-data-cleaning-pipeline)
8. [Program → table/figure map](#8-program--tablefigure-map)
9. [Re-running with new years — step-by-step](#9-re-running-with-new-years--step-by-step)
10. [Companion documents](#10-companion-documents)

---

## 1. Overview of the study

Hurricanes **Katrina** (Aug 29, 2005) and **Rita** (Sep 24, 2005) displaced
roughly 400,000 school-age children. Because evacuee families were relocated
largely by where buses, shelters, and relatives happened to be—**not** by school
choice—the sudden arrival of evacuees ("Katrina"/"Rita" students) into receiving
schools is treated as a **natural experiment** that injects quasi-random
variation in peer composition. The paper asks how the **share of evacuees** in an
incumbent ("native") student's school/grade/classroom affects the incumbent's:

* **test scores** (math and reading/ELA),
* **attendance** (Houston only), and
* **disciplinary infractions**,

and—its central contribution—what the **structure** of those peer effects looks
like (linear-in-means vs. monotonicity vs. invidious comparison vs.
boutique/ability-grouping vs. "bad apple").

**Two settings / two data systems.**

| | Louisiana (statewide) | Houston (HISD) |
|---|---|---|
| Tests | LEAP / iLEAP / GEE | TAKS (math & reading) |
| Years (core) | 2003-04 → 2006-07 (placebo back to 1999-00) | 2003-04 → 2006-07 (cleaning files reach back to 1993-94) |
| Levels | grades 3–10 | grades 1–12 |
| Extra outcomes | discipline | attendance, discipline, **classroom-level** links |
| IV available? | no | **yes** (Sept-13-2005 share) |

**Identification.** A difference-in-differences / value-added specification:
incumbent outcome regressed on the evacuee share, with **school fixed effects**,
**grade effects**, **year effects**, **grade×year interactions**, demographic
controls, and (in the published version) **lagged pre-Katrina achievement**
interacted with the number of years between exams. The evacuee share is **0 in
all pre-2005-06 years**, so identification comes from the change in incumbent
outcomes in high- vs. low-evacuee schools after the storms.

**Instrument (Houston only).** Evacuees re-sorted across schools during the fall
of 2005, so the late-October share is endogenous to school quality. The paper
instruments it with the **September 13, 2005 evacuee share** (two weeks after
landfall, *excluding* students still living in the Astrodome/Reliant/George R.
Brown mega-shelters, who almost all moved within two weeks).

**Structure-of-peer-effects ("quartile") analysis.** Incumbents and evacuees are
sorted into **pre-Katrina achievement quartiles**; the evacuee share is split by
the quartile the evacuees fall in, and interacted with the incumbent's own
quartile, producing a 4×4 matrix of coefficients whose pattern discriminates
between competing peer-effect models.

A full, accurate list of all main-text Tables 1–11/Figures 1–6 and Appendix
Tables 1–46/Figures 1–7 is in **[`docs/CLEANING_AND_DECISIONS.md`](docs/CLEANING_AND_DECISIONS.md)**
and the [program map](#8-program--tablefigure-map) below.

---

## 2. What is in this package

```
Imberman Replication/
├── README.md                     ← you are here (detailed replication guide)
├── master.do                     ← single entry point / canonical run order
├── imberman-kugler-sacerdote-2012-aer.pdf  ← published paper (AER 2012, 102(5):2048–82)
├── 20091305_app.pdf              ← published online appendix (App. Tables 1–46)
├── w15291.pdf                    ← earlier NBER working-paper version
├── LICENSE.txt
├── docs/
│   ├── CLEANING_AND_DECISIONS.md ← the cleaning pipeline + every key judgment call
│   └── PROGRAMS_AND_COMMANDS.md  ← the reusable code routines & SSC commands used
├── website/                      ← static replication site
│   ├── index.html                ← overview (this README, formatted)
│   ├── files.html                ← in-page browser/viewer for every file
│   └── search.html               ← full-text keyword search across all dofiles
└── programs/                     ← all 80 Stata .do files (now fully commented)
    ├── replication-readme.pdf    ← authors' original one-page readme (kept for reference)
    └── *.do
```

> **Note:** the raw and intermediate **`.dta` data files are *not* included** —
> they are proprietary (see §4). Every `.do` file is included and has been
> annotated with a standard header (purpose, inputs, outputs, the table it
> produces, and the hardcoded years/paths to change for a new-years run).

---

## 3. Software and dependencies

* **Stata** (developed under Stata 11/12; runs under any modern Stata). The code
  uses `set mem` (a no-op in Stata ≥ 12) and `xi:`-style interactions, both of
  which still work but are deprecated—see notes in `master.do`.
* **User-written (SSC) commands** — install once:

  ```stata
  ssc install outreg2      // exports regression results to the result tables
  ssc install quantiles    // sorts observations into quantile groups (builds quartiles)
  ssc install renames      // batch variable renaming (used in taks_append.do)
  ```

  Everything else (`areg`, `ivreg`, `ivreg2`, `xtreg`, `xi`, `test`, `lincom`,
  `collapse`, `reshape`, `egen … pctile`) is official Stata. The original
  cleaning files also used `odbc load` to pull from Access/SQL data sources at
  HISD; you will not need ODBC unless you are rebuilding from the same raw
  database dumps.

See **[`docs/PROGRAMS_AND_COMMANDS.md`](docs/PROGRAMS_AND_COMMANDS.md)** for what
each of these does and how the authors use it.

---

## 4. Data access (the data are proprietary)

Neither district nor state will allow the micro-data to be posted. To obtain it:

* **Houston (HISD).** Submit a research proposal to the **Houston Independent
  School District Research & Accountability Department**
  (`houstonisd.org` → Research & Accountability). State in the request that you
  want the data provided **directly by the authors**. On receipt of HISD's
  written permission and a copy of your approval letter, the authors will share
  both the original and intermediate datasets.
* **Louisiana.** Request student-level criterion-referenced test data from the
  **Louisiana Department of Education, Division of Standards, Assessment &
  Accountability** (administered via Data Recognition Corporation).

Because the data cannot be shipped, this package is primarily a **code +
documentation** replication: it lets a reader (a) verify exactly how every number
was produced and (b) reproduce the results once they have obtained the same data
under their own agreement, **or** apply the identical pipeline to new years.

---

## 5. Directory and path conventions

The original `.do` files were written across three of the authors' machines and
contain **hardcoded absolute paths**. You will see, verbatim, things like:

| Hardcoded root in the code | What lived there | Maps to (in `master.do`) |
|---|---|---|
| `/work/i/imberman/imberman/` | analysis datasets (`katrina_data*.dta`, `hisd_data.dta`) | `$work` |
| `/work/i/imberman/imberman/la_data/` | Louisiana prepped data | `$work/la_data` |
| `/home/s/simberman/work/hisd/katrina/` | Houston cleaning intermediates | `$raw` / `$work` |
| `C:\D\Research\Charter\Houston\HISDdata\...` | raw HISD extracts (Windows) | `$raw` |

`master.do` defines four globals — `$root`, `$prog`, `$raw`, `$work` (+ `$out`) —
in **one place** at the top. Stata cannot retroactively redirect a path that is
already written into a `use`/`save`/`cd` statement, so to run end-to-end you must
**repoint the hardcoded roots** to those globals (a one-time find/replace; see
§9, step 2). Each `.do` file's header lists the exact paths it contains under
*"HARDCODED YEARS / PATHS TO UPDATE."*

---

## 6. How to run the analysis (`master.do`)

1. Open **`master.do`** and edit the four `global` lines in section 0 to match
   your machine.
2. Install the three SSC commands (§3).
3. Obtain and stage the data (§4) under `$raw` / `$work`.
4. Repoint the hardcoded paths inside the `.do` files (§9, step 2).
5. Un-comment the `do` lines you want to run, **in the order given**:
   **Part A** (LA cleaning) → **Part B** (Houston cleaning) → **Part C** (Houston
   dataset construction) → **Part D/E** (analysis, by table).

The cleaning order is **load-bearing**: `merge_c.do` (the Houston master merge)
consumes the outputs of `attendence.do`, `demographics_clean.do`,
`taks_append.do`, and `discipline.do`; the analysis files consume the outputs of
`merge_c.do`, `quartile_data.do`, and the LA standardization files. Running an
analysis file before its inputs exist will fail on a missing `.dta`.

---

## 7. The data-cleaning pipeline

A short version is below; the **full** narrative—including every sample
restriction and judgment call—is in
**[`docs/CLEANING_AND_DECISIONS.md`](docs/CLEANING_AND_DECISIONS.md)**.

### Houston (HISD)
```
attendence.do          ─┐ enrollment, attendance %, evacuee location code → katrina flag
demographics_clean.do  ─┤ race / gender / lunch / DOB / program flags
taks_append.do         ─┼─►  merge_c.do  ──►  hisd_data.dta
discipline.do          ─┘    (master merge)        │
(stanford/aprenda/taas/student-teacher extracts)   │
                                                    ├─► katrina_data_with_evacs.dta (incumbents+evacuees)
                                                    ├─► katrina_data.dta            (incumbents only)
                                                    └─► maxgrade.dta                (top grade per school)
                                                    │
                       quartile_data.do  ──► pre_katrina_quartiles.dta
                       quintile_data.do / placebo_quartile_data.do
```
`merge_c.do` is the heart of the Houston build: it standardizes TAKS scores to
SD units within grade×year (using **statewide** means/SDs hardcoded in the file),
constructs the **evacuee shares** at campus / grade / class level, builds the
**September-13-2005 instrument** (including the shelter subtraction), imputes
time-invariant demographics and grade, and restricts to students enrolled in
2005-06 (the only year evacuee status is observed).

### Louisiana
```
alt_scale.do          collapse raw LEAP/iLEAP/GEE scale scores
alt_standardize.do    standardize within grade×year (all test-takers)
alt_standardize_2.do  standardize using ONLY non-evacuees           → alternative_standardization.dta
school_level_means.do collapse to school-level (placebo / pre-trend inputs)
```

---

## 8. Program → table/figure map

> Main-text tables are **T1–T10**; appendix tables **A2–A46**. A file can feed
> several tables; the workhorse `quartile_analysis_revision_d.do` alone produces
> Tables 5 & 7 and roughly a dozen appendix tables. Robustness variants ending in
> `_nolag` / `_nolagint` produce the "no lag" / "lag-not-interacted" rows of the
> achievement appendix tables.

### Data construction
| File | Produces |
|---|---|
| `attendence.do`, `demographics_clean.do`, `taks_append.do`, `discipline.do` | Houston cleaned domain files |
| `merge_c.do` | `hisd_data.dta`, `katrina_data*.dta`, evacuee shares, the IV, quartiles |
| `quartile_data.do`, `quintile_data.do`, `placebo_quartile_data.do` | incumbent baseline quartiles/quintiles |
| `alt_scale.do`, `alt_standardize.do`, `alt_standardize_2.do` | LA standardized scores |
| `school_level_means.do` | LA school-level means |

### Main-text tables
| Table | Program(s) |
|---|---|
| **T1** Descriptives | `summary_stats_la.do`; `sumstats_houston.do`; `sumstats_b.do` |
| **T2** Evacuee–native gaps | `analysis_revision_linear.do`; `katrina_nonkatrina.do` |
| **T3** DiD, native test scores (HOU) | `katrina_by_quartiles_va_grade_statestd.do`; `katrina_iv_gender_ethnicity_noshelter_grade.do`; `katrina_placebotest_grade.do` |
| **T4** Nonlinear evacuee×quartile (HOU) | `katrina_by_quartiles_lim_test_fullint_math.do`; `…_read.do`; `katrina_by_quartiles_pre_katrina_ols.do` |
| **T5** Nonlinear 4×4 matrix (LA) | `analysis_revision_linear.do`; `quartile_analysis_revision_d.do` |
| **T6** Epple–Romano linear-in-means | `epple_romano_f_ela_grade_fullintb.do`; `epple_romano_f_math_grade_fullintb.do` |
| **T7** Bad-apple (evacuee behavior) | `quartile_analysis_revision_d.do` |
| **T8** Peer-structure model tests | `quartile_analysis_revision_full_b_tests_nobon.do` |
| **T9** Class size | `school_level_placebo_b.do`; `school-trend.do` |
| **T10** Attendance & discipline DiD (HOU) | `katrina_by_quartiles_va_grade_statestd.do`; `katrina_iv_gender_ethnicity_noshelter_grade.do` |

### Appendix tables
| App. | Program(s) |
|---|---|
| **A2** | `sumstats_b.do`; `summary_stats_la.do` |
| **A3** | `katrina_by_quartiles_va.do`; `katrina_iv_gender_ethnicity_noshelter.do` |
| **A4 & A5** (HOU spec. battery, in order) | `katrina_iv_c.do`; `katrina_by_quartiles_va_fe.do`; `…_va_class.do`; `…_va_outlier.do`; `…_va_intpanel.do`; `katrina_by_quartiles_0405inst.do`; `…_va_scale.do`; `…_attrition.do`; `…_va_grade_altstd.do`; `…_va_campusyear.do`; `…_va_campusgrade.do`; `…_va_totenroll.do`; `…_va_newentrant.do`; `…_va_nozero.do` |
| **A6** | `katrina_by_quartiles_va_quintiles.do` |
| **A7** | `katrina_by_quartiles_avgweeklyenroll_b.do` |
| **A8** | `katrina_by_quartiles_halfyear_enroll.do` |
| **A9 & A10** | `katrina_by_quartiles_lim_test_fullint_math.do`; `…_read.do` (+ `_nolag` / `_nolagint` variants) |
| **A11** | `katrina_by_quartiles_testtaking.do`; `check_non_test_takers2.do` |
| **A12 & A13** | `analysis_revision_linear.do`; `quartile_analysis_revision_d.do` |
| **A14** | `epple_romano_f_ela_grade_fullintb.do`; `epple_romano_f_math_grade_fullintb.do` |
| **A15–A19, A21–A22, A27–A28, A30, A32–A37, A39, A43** | `quartile_analysis_revision_d.do` |
| **A20** | `quartile_analysis_revision_full_b_tests_nobon.do` |
| **A23 & A24** | `quartile_analysis_revision_full_trends_b.do` |
| **A25 & A26** | `school_level_placebo_b.do`; `school-trend.do` |
| **A29** | `quartile_analysis_revision_full_scale.do` |
| **A31** | `quartile_analysis_revision_full_FE_b.do` |
| **A38** | `quartile_analysis_revision_alt_standard2.do` |
| **A40** | `katrina_iv_gender_ethnicity_noshelter_grade.do` |
| **A41** (HOU behavior battery) | `katrina_iv_c.do`; `…_va_fe.do`; `…_va_outlier.do`; `…_va_intpanel.do`; `katrina_by_quartiles_0405inst.do`; `…_va_campusyear.do`; `…_va_campusgrade.do`; `…_va_totenroll.do`; `…_va_newentrant.do`; `…_va_nozero.do` |
| **A42** | `katrina_by_quartiles_avgweeklyenroll_b.do` |
| **A44** | `analyze_school_level2_quartiles_b.do` |
| **A45** | `katrina_resources.do` |
| **A46** | `katrina_by_quartiles_leave.do` |

*Helper / scratch:* `quartile_analysis_revision_trends.do`,
`…_0405inst.do`, `…_quintiles.do`, `…_full_b_tests.do`,
`katrina_iv_c_grade.do`, `katrina_placebotest_c.do`,
`katrina_by_quartiles_va_outlier_8.do`,
`katrina_by_quartiles_lim_test_*` combined drivers, and
`extra_stuff*.do` (numbers cited in text/footnotes).

---

## 9. Re-running with new years — step-by-step

The single biggest obstacle to extending this code is that **years are hardcoded
throughout** (in loops, sample filters, the standardization constants, the
instrument, and the "shift 2006 back to 2005" rules). This section is a practical
checklist. Suppose you have obtained, say, **2007-08 and 2008-09** data and want
to add them.

> **Conceptual caveat first.** The research design is anchored to a one-time
> shock in **2005-06**. Adding *later* years extends the *post* period (useful for
> persistence/dynamics and for the placebo/pre-trend logic); it does **not**
> create a new treatment. If instead you want to apply the *method* to a
> different shock or district, treat the year that the new evacuees/transfers
> arrive as the new "2005-06" and shift every year reference accordingly. Either
> way, the mechanical steps are the same.

### Step 1 — Stage the new raw data in the same shape
Make the new-year extracts match the existing layout (same variable names, the
same per-year file naming the loaders expect). In particular:
* Houston attendance/demographics loaders append per-year files named like
  `ada-2005-06`, `demog_2006`, `taks_2006_eng_a`, etc. — add `…_2007`, `…_2008`
  files following the identical convention.
* Louisiana uses a single long file (`LA_leap00_09.dta` already spans 2000-09);
  confirm the new years are present and that `grade` is coded consistently
  (`"HS"`→10, etc., as in `alt_standardize.do`).

### Step 2 — Repoint the hardcoded paths (one-time)
From the `programs/` folder, replace each absolute root with your global. For
example (adapt to your shell / do-file editor; **back up first**):
```
/work/i/imberman/imberman/la_data   →   <your $work>/la_data
/work/i/imberman/imberman           →   <your $work>
/home/s/simberman/work/hisd/katrina →   <your $work>
C:\D\Research\Charter\Houston\HISDdata\DataFiles  →  <your $raw>
```
Each file's header lists exactly which of these it contains.

### Step 3 — Extend every hardcoded **year range**
Search the whole `programs/` folder for year literals and widen them. The
recurring patterns to update (every annotated file flags its own with a
`// YEAR HARDCODE` comment):

| Pattern (examples) | Where | What to change |
|---|---|---|
| `forvalues year = 1997/2006` / `2000/2007` | `merge_c.do`, `alt_standardize.do` | extend the upper bound to your last year |
| `keep if year >= 2002` ; `keep if year>=2000 & year<=2007` | `merge_c.do`, `quartile_analysis_revision_d.do` | widen the window |
| `replace katrina = 0 if year < 2005` | everywhere | keep `2005` as the treatment onset (evacuee share = 0 before it) unless you are re-anchoring the design |
| `gen enroll_0506 = …` / "limit to students enrolled in 2005-06" | `merge_c.do` | this restricts the sample to the cohort observed when evacuee status was recorded — **do not blindly widen**; decide whether new years should be conditioned on 2005-06 enrollment (persistence sample) or treated as a fresh panel |
| `replace … = l.… if year == 2006` (carry 2005 evacuee quartiles forward) | `merge_c.do`, `quartile_data.do` | the "2006 inherits 2005" rule reflects that evacuee status/quartile was fixed in 2005; replicate the logic for any additional post-years |
| `*_9_13_05`, `shelter_…_05`, `enroll_campus_05` (the **Sept-13-2005 instrument**) | `merge_c.do`, `katrina_iv_*` | these are dated to 2005 by construction — leave as the instrument; they are 0 for all other years |

### Step 4 — Rebuild the **score standardization** for the new years
Two distinct mechanisms must both be extended:
1. **Within grade×year standardization loops** (e.g. `merge_c.do` lines that loop
   `foreach year of numlist 1997/2006`): just extend the numlist. These recompute
   means/SDs from the data, so new years are handled automatically once in range.
2. **Hardcoded statewide TAKS mean/SD constants** in `merge_c.do`
   (`replace taks_sd_min_read = (taks_scale_min_read - 2254.6)/183.45 if grade==3 & year==2002`,
   … through 2008). These are **state-published numbers**; there is no value for a
   year you have not entered. For each new year you must obtain the official
   statewide grade-level mean and SD and add a parallel block of `replace` lines,
   **or** switch that section to the data-driven `summarize`/`replace` loop the
   file already contains (currently commented out) so SDs are computed from your
   sample. The companion doc explains both options.
   The Louisiana side standardizes from the data (`alt_standardize.do` builds
   `la_means.dta` by `collapse (mean)(sd) … , by(grade year)`), so LA needs no
   hardcoded constants—just make sure the new years survive the standardizing-
   sample filter (`everkatrina==0 & katrina_district2==0 & percent_katrina<.7`).

### Step 5 — Extend the **baseline-quartile** construction
Quartiles are formed from each student's **pre-Katrina** score (2003-04, falling
back to 2002-03 in Houston; 2003-04→2002-03 in LA). For a persistence analysis
those baselines stay fixed. The files explicitly **blank out** quartiles for
grade/year cells that lack a critical mass (e.g. in `quartile_data.do`,
`replace … = . if grade==3 & year==2005`). If your new years introduce newly
tested grades, revisit these `replace … = .` rules so you do not silently drop or
mis-assign cells.

### Step 6 — Extend the **grade×year fixed effects**
Interactions are built with `xi: i.grade*i.year` / `xi i.grade_num*i.year` or by
hand (`gen gradeyear = grade + year*100 ; tab gradeyear, gen(gradeyear_)`). These
expand automatically with the data, but check any place where specific dummies
are **named** or **dropped** (e.g. omitting the 2005 interaction as the base
category) and make sure the base category is still what you intend.

### Step 7 — Re-run and reconcile
Run `master.do` Parts A→E in order. Expect sample sizes (and therefore every
estimate) to change once new years enter. Before trusting new results:
* confirm `tab year` and `tab _merge` after each merge look sensible,
* re-check the placebo/pre-trend files (`school-trend.do`,
  `school_level_placebo_b.do`, the `katrina_placebotest_*` files) — extending the
  pre-period is the cleanest way to validate that the design still holds, and
* diff your reproduction of the **original** years against the published tables
  *before* adding new years, so any divergence is attributable to the new data,
  not to a path/standardization mistake.

A condensed, copy-pasteable version of this checklist also appears at the top of
each annotated `.do` file (the *"HARDCODED YEARS / PATHS TO UPDATE"* header block).

---

## 10. Companion documents

* **[`docs/CLEANING_AND_DECISIONS.md`](docs/CLEANING_AND_DECISIONS.md)** — a
  narrative walk-through of the entire cleaning process and the key analytical
  decisions (sample restrictions, standardization, evacuee-share construction,
  the instrument, quartile sorting, imputation rules), with the rationale the
  authors give for each.
* **[`docs/PROGRAMS_AND_COMMANDS.md`](docs/PROGRAMS_AND_COMMANDS.md)** — the
  reusable code routines the authors built and re-use across files (the
  standardization loop, the evacuee-fraction generator, the `areg` peer-effects
  specification, the `test`/`lincom` model-structure tests, the `outreg2` export
  pattern) plus the third-party SSC commands the package depends on.
* **`website/index.html`** — a self-contained HTML rendering of this README in a
  journal-replication layout.
* **`master.do`** — the runnable orchestration file.

---

*This README and the companion documents were prepared as part of a replication
review. Every original `.do` file has been annotated with documentation comments
only; **no executable code was altered**, so results reproduce exactly as in the
authors' original package.*
