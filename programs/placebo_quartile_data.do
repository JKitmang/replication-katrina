*===============================================================================
* FILE:     placebo_quartile_data.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Robustness/variant (dataset construction)
* PRODUCES: Intermediate dataset pre_katrina_quartiles_placebo.dta — baseline
*           quartiles for the PLACEBO test (pretends Katrina hit a year earlier),
*           feeding katrina_placebotest_grade (Table 3) and related placebo
*           programs.
*
* PURPOSE:  Same construction as quartile_data.do but shifted one year earlier to
*           build a falsification ("placebo") sample: it restricts to pre-Katrina
*           years (<=2005), uses the 2003 score (else 2002) as the baseline, and
*           sorts students into quartiles within grade x year. This lets the
*           placebo analysis test for "effects" in years before any evacuees
*           actually arrived.
*
* INPUTS:   hisd_data.dta (master Houston panel from merge_c.do)
* OUTPUTS:  pre_katrina_quartiles_placebo.dta (id grade year + *quartile* vars)
*
* KEY STEPS:
*   - Keep pre-Katrina years (<=2005)
*   - Pull each student's per-year score (2002-2003)
*   - BASELINE ACHIEVEMENT QUARTILES (placebo): baseline = 2003 (else 2002);
*     quantiles(4) within grade x year
*   - Blank quartiles for thin grade x year cells (shifted one year vs. main)
*
* HARDCODED YEARS / PATHS TO UPDATE FOR A NEW-YEARS REPLICATION:
*   - use /work/i/imberman/imberman/hisd_data.dta                          (PATH)
*   - save /work/i/imberman/imberman/pre_katrina_quartiles_placebo.dta     (PATH)
*   - keep if year <= 2005 (placebo pre-treatment window)                  (YEAR HARDCODE)
*   - forvalues year = 2002/2003 (per-year score extraction)               (YEAR HARDCODE)
*   - baseline split = `var'_2003 then `var'_2002                          (YEAR HARDCODE)
*   - quartile blanking: grade 3 in 2004/2005, grade 4 in 2005             (YEAR HARDCODE)
*
* NOTE: Documentation comments only — no executable code was modified.
*===============================================================================
***CREATES DATASET WITH NATIVE STUDENT QUARTILES***

clear
set mem 3g
set matsize 2000
set more off

  *OPEN TEMPORARY DATAFILE SAVED EARLIER IN PROGRAM
  use /work/i/imberman/imberman/hisd_data.dta, clear   // PATH: repoint to your local globals

  *LIMIT TO PRE-KATRINA YEARS
  keep if year <= 2005   // YEAR HARDCODE: placebo restricts to pre-Katrina years

  * ---- Pull each student's per-year score (2002-2003) ----
  *GENERATE SCORES FOR EACH YEAR
  foreach depvar of varlist taks_sd_min_math taks_sd_min_read {
     forvalues year = 2002/2003 {   // YEAR HARDCODE: placebo baseline window 2002-2003
      gen temp = `depvar' if year == `year'
      egen `depvar'_`year' = max(temp), by(id)
      drop temp
     }
  }

  * ---- BASELINE ACHIEVEMENT QUARTILES (placebo): baseline = 2003 (else 2002), nq(4) by grade x year ----
  *IDENTIFY NATIVE STUDENTS' PRE-KATRINA QUARTILE
    foreach var of varlist taks_sd_min_math taks_sd_min_read {
	gen `var'_split = `var'_2003                         // YEAR HARDCODE: placebo baseline = 2003
	replace `var'_split = `var'_2002 if `var'_split == .  // YEAR HARDCODE: fall back to 2002
	bysort grade year: quantiles `var'_split , gen(`var'_quartile) nq(4) stable   // baseline achievement quartiles (4)
    }

  *SET TO MISSING FOR YEARS AND GRADES WITHOUT A CRITICAL MASS OF STUDENTS
  replace taks_sd_min_math_quartile = . if grade < 3
  replace taks_sd_min_math_quartile = . if grade == 3 & year == 2004   // YEAR HARDCODE: thin cell (shifted -1 yr)
  replace taks_sd_min_math_quartile = . if grade == 3 & year == 2005   // YEAR HARDCODE: thin cell (shifted -1 yr)
  replace taks_sd_min_math_quartile = . if grade == 4 & year == 2005   // YEAR HARDCODE: thin cell (shifted -1 yr)

  replace taks_sd_min_read_quartile = . if grade < 3
  replace taks_sd_min_read_quartile = . if grade == 3 & year == 2004   // YEAR HARDCODE: thin cell (shifted -1 yr)
  replace taks_sd_min_read_quartile = . if grade == 3 & year == 2005   // YEAR HARDCODE: thin cell (shifted -1 yr)
  replace taks_sd_min_read_quartile = . if grade == 4 & year == 2005   // YEAR HARDCODE: thin cell (shifted -1 yr)



  * ---- Save placebo baseline quartile lookup (input to placebo tests, Table 3) ----
  keep id grade year *quartile*
  sort id year
  save /work/i/imberman/imberman/pre_katrina_quartiles_placebo.dta, replace   // PATH: repoint to your local globals

