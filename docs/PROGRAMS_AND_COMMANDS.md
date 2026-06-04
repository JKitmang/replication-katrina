# Programs & Commands Reference

*Companion to the main [README](../README.md). This document explains the
**reusable code routines the authors built** and the **third-party commands the
package depends on**, so you can read any analysis `.do` file fluently and adapt
it safely.*

The package contains **no formal `program define` subroutines**. Instead, the
authors work through a small set of **recurring code idioms** that are copied
(with small edits) across the ~70 analysis files. Learn these eight idioms and
you can read every file in the package. Each is shown in the exact form it
appears, with the variation across files noted.

---

## Part 0 — The repeated routines ("de-facto programs")

The authors wrote **no Stata `program` / `program define` blocks** (a full-text
search for `program` finds only the word in comments — try it on the
[Search-code page](../website/search.html)). What they *do* reuse are **two large
blocks of data-preparation code that are copied, nearly verbatim, into dozens of
files** — these are the de-facto "programs" of the package. Knowing them means you
read each analysis file's first ~150 lines once and then skim them everywhere else.
Because they are copied (not `include`d), **any change — a year, a path, a control
— must be made in every copy**; the Search-code page is the fastest way to find
all copies.

### Routine 1 — the **Louisiana analysis preamble**
*Signature to find every copy:* search `la_prepped_revisionFULL_SAMPLE` (or
`alternative_standardization`).

**What it does (in order):** `use` the prepped LA student panel
(`la_prepped_revisionFULL_SAMPLE.dta`); merge the standardized scores
(`alternative_standardization.dta`); build each student's best **pre-2006** score
(`math0005`/`ela0005`) and the most-recent **pre-Katrina lag** (`math_lag`/`ela_lag`,
capped so the lag is always pre-treatment); sort incumbents into **baseline
achievement quartiles** (`quantiles … nq(4) stable`, by `grade_num`×`year`); build
**grade×year** interactions (`xi i.grade_num*i.year`); apply the **sample window**
(`keep if year>=2000 & year<=2007`, `grade_num` 4–10, drop thin grade/year cells);
define the **lag sample** (grades/years for which a pre-Katrina score exists); and
merge in the **discipline** and **test-administrator** files.

**Where it appears (24 files):** `analysis_revision_linear`,
`quartile_analysis_revision_d`, `…_alt_standard2`, `…_trends`, `…_0405inst`,
`…_full_b_tests`, `…_full_b_tests_nobon`, `…_full_FE_b`, `…_full_scale`,
`…_full_trends_b`, `…_quintiles`, `epple_romano_f_{math,ela}_grade_fullintb`
(+ `_nolag`, `_nolagint`), `summary_stats_la`, `school_level_means`,
`check_non_test_takers2`, `extra_stuff`. (Its inputs are built by `alt_scale`,
`alt_standardize`, `alt_standardize_2`.)

### Routine 2 — the **Houston analysis preamble**
*Signature to find every copy:* search `katrina_data.dta` (or `lagyears_`).

**What it does (in order):** `use` the incumbent file (`katrina_data.dta`; some
files start from `hisd_data.dta`); `xtset id year`; build **pre-Katrina (`<=2004`)
lags** of math, reading, attendance and infractions, each with a
"years-since-lag" counter; merge the **baseline quartiles**
(`pre_katrina_quartiles.dta`); (re)build the **evacuee fractions** at campus /
grade / class level and the **by-quartile evacuee shares**; build **grade×year**
dummies; apply sample restrictions; and loop over **grade level**
(`elem`, `midhigh`).

**Where it appears (≈40 files):** the entire `katrina_by_quartiles_*` family,
`katrina_iv_c` / `katrina_iv_c_grade`,
`katrina_iv_gender_ethnicity_noshelter` / `…_grade`,
`katrina_placebotest_c` / `…_grade`, and `extra_stuff_houston`.

> The smaller reusable fragments **inside** these two preambles — the
> standardization loop, the lag builder, the quartile sorter, the evacuee-fraction
> generator, the Sept-13-2005 instrument, the `areg`/`ivreg` estimators, and the
> `suest`+`test` model battery — are catalogued individually as Idioms 1–8 in
> Part II below.

---

## Part I — Third-party (SSC) commands the package requires

| Command | What it does | Where it's used | Install |
|---|---|---|---|
| **`quantiles`** | Sorts observations into *k* equal-frequency groups (here, achievement **quartiles**/quintiles) within `bysort` cells. `nq(4) stable` → quartiles with a stable sort. | `quartile_data.do`, `quintile_data.do`, `quartile_analysis_revision_*` | `ssc install quantiles` |
| **`outreg2`** | Writes regression results to a formatted table file (the result tables). | nearly every analysis file (`outreg`/`outreg2` appear ~780×) | `ssc install outreg2` |
| **`renames`** | Renames many variables in one statement (`renames old1 old2 \ new1 new2`). | `taks_append.do` | `ssc install renames` |

Everything else is **official Stata**: `areg`, `ivreg`, `ivreg2`, `xtreg`,
`xi`, `test`, `lincom`, `suest`, `collapse`, `reshape`, `egen … pctile`,
`tsset`/`xtset`, `aorder`/`order`. The cleaning files additionally use **`odbc
load`** to pull per-year tables from the districts' Access/SQL databases — only
relevant if you rebuild from the same raw dumps.

> **Version note.** The code was written under Stata 11/12. It uses `set mem`
> (ignored in Stata ≥ 12) and `xi:`-prefix interaction syntax (still supported,
> but `i.`-factor variables are the modern equivalent). It will run as-is in
> current Stata; if you modernize, replace `xi` with factor-variable notation and
> `areg … , absorb()` with `reghdfe` for multi-way FE.

---

## Part II — The authors' reusable routines (code idioms)

### Idiom 1 — Within-grade×year score **standardization**
Converts a raw scale score into SD units, *excluding evacuees* from the moments.
Appears in `merge_c.do` (legacy tests) and, data-driven, in `alt_standardize.do`.

```stata
foreach var in "stanford_read" "stanford_math" "stanford_lang" {
    gen `var'_sd = .
    foreach grade of numlist 1/11 {
        foreach year of numlist 1997/2006 {        // <- YEAR RANGE to extend
            sum `var'_scale if grade==`grade' & year==`year' & (katrina==0 | katrina==.)
            replace `var'_sd = (`var'_scale - r(mean))/r(sd) if grade==`grade' & year==`year'
        }
    }
}
```
**Variant — hardcoded statewide moments (TAKS, `merge_c.do`).** Instead of
`summarize`, the SD is computed from **state-published** grade×year mean/SD
constants, one `replace` line per (grade, year): `… (taks_scale_min_read −
2254.6)/183.45 if grade==3 & year==2002`. *To add a year you must supply that
year's official statewide mean/SD, or switch this block to the `summarize` form
above.* See README §9 step 4.

### Idiom 2 — **Lag** of a test score (most recent *pre-Katrina* score)
Builds the lagged-achievement control. Appears in `alt_standardize.do` and the
analysis files.

```stata
gen check1 = 1 if id==id[_n-1]
gen math_lag = mathSTD[_n-1] if check1==1 & mathSTD!=. & mathSTD[_n-1]!=.
...
* cap the lag at a pre-2006 score so the control is always pre-treatment:
replace math_lag = math0005 if year>2005     // math0005 = best score 2000–2005
```
The `*_nolag` files delete the lag entirely; the `*_nolagint` files keep
`math_lag` but **do not** interact it with quartiles / years-between-exams.

### Idiom 3 — **Baseline-achievement quartiles**
Predetermined quartile from a pre-period score, with thin cells blanked.

```stata
gen taks_sd_min_math_split = taks_sd_min_math_2004        // pre-Katrina score
replace taks_sd_min_math_split = taks_sd_min_math_2003 if taks_sd_min_math_split==.
bysort grade year: quantiles taks_sd_min_math_split, gen(taks_sd_min_math_quartile) nq(4) stable
replace taks_sd_min_math_quartile = . if grade<3            // blank thin grade/year cells
replace taks_sd_min_math_quartile = . if grade==3 & year==2005
tab taks_sd_min_math_quartile, gen(mathQD)                 // -> dummies mathQD1..mathQD4
```

### Idiom 4 — The **evacuee share** (treatment) and its quartile split
The single most important constructed variable. Built at campus / grade / class
level in `merge_c.do` and re-built (school-grade) in the LA analysis files.

```stata
gen unit = 1
egen katrina_count_grade = sum(katrina), by(campus grade year)   // # evacuees in cell
egen enroll_grade        = sum(unit),    by(campus grade year)   // total in cell
gen  katrina_frac_grade  = katrina_count_grade/enroll_grade      // = the treatment

* split the share by the quartile the EVACUEES fall in:
gen katrina_quartile_4_math = katrina*taks_sd_min_math_quartile_4
replace katrina_quartile_4_math = l.katrina_quartile_4_math if year==2006  // carry 2005 fwd
egen katrina_count_math_quartile_4 = sum(katrina_quartile_4_math)
gen  katrina_frac_math_quartile_4  = katrina_count_math_quartile_4/enroll_campus
```
By-gender (`katrina_girls`/`katrina_boys`) and by-race
(`katrina_frac_black`/`_hisp`) interacted shares are built the same way. **All
shares are 0 before 2005-06.**

### Idiom 5 — The **September-13-2005 instrument** (Houston 2SLS)
Lives in `merge_c.do`; consumed by the `katrina_iv_*` files.

```stata
* subtract mega-shelter residents (they relocated within ~2 weeks):
gen katrina_enroll_noRGB_9_13_05 = katrina_enroll_9_13_05 - astrodome_9_13 ///
        - reliant_center_9_13 - george_brown_9_13 - reliant_arena_9_13
* estimate 9/13 enrollment (total 9/13 headcount is unobserved):
gen enroll_9_13_05      = enroll_campus_05 - katrina_enroll_10_31_05 + katrina_enroll_9_13_05
gen katrina_frac_9_13_05 = katrina_enroll_9_13_05/enroll_9_13_05      // = the instrument
replace katrina_frac_9_13_05 = 0 if year<2005                        // 0 in all other years
```

### Idiom 6 — The **difference-in-differences / value-added** regression
The workhorse estimator: school fixed effects absorbed, SEs clustered by school,
grade×year interactions as controls.

```stata
xi i.grade*i.year                                        // grade×year FE (prefix _I*)
areg  taks_sdstate_min_math  katrina_frac_grade          /// the treatment
      ltaks_sdstate_min_math_*                            /// lagged-score controls (interacted)
      female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* ///
      if taks_sd_min_math_quartile != ., absorb(campus) cluster(campus)
```
* `absorb(campus)` = **school fixed effects** (the diff-in-diff core).
* `cluster(campus)` = inference clustered at school (some behavior tables cluster
  by grade instead).
* The coefficient on `katrina_frac_grade` is the **peer effect** reported in the
  reduced-form tables (T3, T6/T10, App. 3–5, 40–41).
* Robustness files swap one ingredient: `…_va_fe` (student FE), `…_va_outlier`
  (trim outliers), `…_va_scale` (unstandardized y), `…_va_campusyear` /
  `…_va_campusgrade` (different absorbed FE), `…_va_totenroll` (control total
  enrollment), `…_va_nozero` (drop zero-evacuee schools), etc.

### Idiom 7 — The **2SLS** and **Epple–Romano linear-in-means** estimator
For the instrument-based and linear-in-means tables (T4–T6, App. 9–10, 14).

```stata
* OLS form: regress own score on peer-MEAN achievement, interacted with own quartile
reg   mathSTD peer_mean_Q1 peer_mean_Q2 peer_mean_Q3 peer_mean_Q4 controls gryr* _g* , cluster(sitecode)

* 2SLS form: instrument the endogenous peer means with the evacuee CONTRIBUTION
ivreg mathSTD (peer_mean_Q1 peer_mean_Q2 peer_mean_Q3 peer_mean_Q4 = ///
               contribution_katrina_Q1 contribution_katrina_Q2 ///
               contribution_katrina_Q3 contribution_katrina_Q4) controls gryr* _g*, cluster(sitecode)
```
where the peer mean **excludes own observation**
(`peer_mean=(sum_score−ownscore)/(n−1)`) and the instrument is the evacuees'
contribution to the **lagged** peer mean (`evac_lag_mean × evac_share`).

### Idiom 8 — The **peer-structure model tests** (SUR + Wald)
How Tables 8 / App. 20 decide between monotonicity, invidious comparison,
ability-grouping/boutique, and the bad-apple propositions. In
`quartile_analysis_revision_full_b_tests*.do`.

```stata
forvalues quart = 1/4 {                          // one regression per OWN quartile
    reg mathSTD math_lag_* Kfraction_mathQ1G Kfraction_mathQ2G ///
        Kfraction_mathQ3G Kfraction_mathQ4G controls gryr* _I* if mathQD`quart'==1
    estimates store math`quart'
}
suest math1 math2 math3 math4, vce(cluster sitecode)     // stack into one covariance system

* each peer-model is a Wald test on the stacked coefficients, e.g. strong monotonicity:
test ([math1_mean]Kfraction_mathQ1G = [math1_mean]Kfraction_mathQ2G ///
    = [math1_mean]Kfraction_mathQ3G = [math1_mean]Kfraction_mathQ4G)
```
* `suest` builds the seemingly-unrelated covariance across the four
  quartile-specific equations so cross-equation coefficients can be compared.
* The **`_nobon`** file runs `test … , mtest` **without** Bonferroni; the sister
  `…_b_tests.do` applies the Bonferroni multiple-comparison adjustment (`mtest(b)`).
* `lincom` is used elsewhere to report individual linear combinations of the 4×4
  matrix (the pairwise comparisons behind Figures 5–6).

---

## Part III — Output / export conventions

* **`outreg2`** appends each estimate to a result file; a file's sequence of
  `outreg2` calls mirrors the **columns/panels** of the corresponding table (the
  annotated headers note which table each block feeds).
* **`test` / `lincom`** results are read **straight from the log** — for the model
  tables (T8, App. 20) the printed Wald statistics *are* the table.
* Some files `save` an intermediate `temp_*.dta` (e.g. `epple_romano_*` saves
  `temp_math.dta`) so the math and ELA halves can share a build.

---

## Part IV — Reading any file quickly

1. **Header** (added in this documentation pass): purpose, inputs, outputs, the
   table it makes, and the hardcoded years/paths to change.
2. **Top third** = data prep: `use` the analysis file, merge quartiles /
   discipline / test-administrator data, rebuild shares (Idioms 1–5).
3. **Middle** = the `xi`/`areg`/`ivreg`/`reg … estimates store … suest` block
   (Idioms 6–8) — the actual estimator.
4. **Bottom** = `outreg2` / `test` / `lincom` that emit the table.

Match the estimator in step 3 to the table via the [program map](../README.md#8-program--tablefigure-map),
and you can trace any published number back to the line that produced it.
