*===============================================================================
* FILE:     quintile_data.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Robustness/variant (dataset construction)
* PRODUCES: Intermediate dataset pre_katrina_quintiles.dta — the QUINTILE
*           (5-bin) analogue of quartile_data.do, feeding the Houston quintile
*           robustness battery (Appendix Table 6:
*           katrina_by_quartiles_va_quintiles).
*
* PURPOSE:  Identical to quartile_data.do but splits each student's pre-Katrina
*           baseline standardized TAKS score (2004, else 2003) into five bins
*           (nq(5)) within grade x year instead of four. Blanks bins for thin
*           grade x year cells.
*
* INPUTS:   hisd_data.dta (master Houston panel from merge_c.do)
* OUTPUTS:  pre_katrina_quintiles.dta (id grade year + *quintile* vars)
*
* KEY STEPS:
*   - Build math-read average score
*   - Pull each student's per-year score (2003-2006)
*   - BASELINE ACHIEVEMENT QUINTILES: baseline = 2004 (else 2003); quantiles(5)
*     within grade x year
*   - Blank quintiles for thin grade x year cells
*
* HARDCODED YEARS / PATHS TO UPDATE FOR A NEW-YEARS REPLICATION:
*   - use /work/i/imberman/imberman/hisd_data.dta                      (PATH)
*   - save /work/i/imberman/imberman/pre_katrina_quintiles.dta         (PATH)
*   - forvalues year = 2003/2006 (per-year score extraction)           (YEAR HARDCODE)
*   - baseline split = `var'_2004 then `var'_2003                      (YEAR HARDCODE)
*   - quintile blanking: grade 3 in 2005/2006, grade 4 in 2006         (YEAR HARDCODE)
*   - set seed 10563 (for tie-breaking in quantiles -stable-)
*
* NOTE: Documentation comments only — no executable code was modified.
*===============================================================================
***CREATES DATASET WITH NATIVE STUDENT QUARTILES***

clear
set mem 3g
set matsize 2000
set more off

set seed 10563   // fixed seed for reproducible quantile tie-breaking

  *OPEN TEMPORARY DATAFILE SAVED EARLIER IN PROGRAM
  use /work/i/imberman/imberman/hisd_data.dta, clear   // PATH: repoint to your local globals

  *GENERATE AVERAGE OF MATH & READING
  gen taks_sd_min_avg = (taks_sd_min_math + taks_sd_min_read)/2

  * ---- Pull each student's per-year score (2003-2006) ----
  *GENERATE SCORES FOR EACH YEAR
  foreach depvar of varlist taks_sd_min_math taks_sd_min_read taks_sd_min_avg{
     forvalues year = 2003/2006 {   // YEAR HARDCODE: extract scores for 2003-2006
      gen temp = `depvar' if year == `year'
      egen `depvar'_`year' = max(temp), by(id)
      drop temp
     }
  }

  * ---- BASELINE ACHIEVEMENT QUINTILES: baseline = 2004 (else 2003), nq(5) by grade x year ----
  *IDENTIFY NATIVE STUDENTS' PRE-KATRINA QUINTILE
    foreach var of varlist taks_sd_min_math taks_sd_min_read taks_sd_min_avg{
	gen `var'_split = `var'_2004                         // YEAR HARDCODE: baseline score = 2004
	replace `var'_split = `var'_2003 if `var'_split == .  // YEAR HARDCODE: fall back to 2003
	bysort grade year: quantiles `var'_split , gen(`var'_quintile) nq(5) stable   // baseline achievement quintiles (5)
    }

  *SET TO MISSING FOR YEARS AND GRADES WITHOUT A CRITICAL MASS OF STUDENTS
  replace taks_sd_min_math_quintile = . if grade < 3
  replace taks_sd_min_math_quintile = . if grade == 3 & year == 2005   // YEAR HARDCODE: thin cell
  replace taks_sd_min_math_quintile = . if grade == 3 & year == 2006   // YEAR HARDCODE: thin cell
  replace taks_sd_min_math_quintile = . if grade == 4 & year == 2006   // YEAR HARDCODE: thin cell

  replace taks_sd_min_read_quintile = . if grade < 3
  replace taks_sd_min_read_quintile = . if grade == 3 & year == 2005   // YEAR HARDCODE: thin cell
  replace taks_sd_min_read_quintile = . if grade == 3 & year == 2006   // YEAR HARDCODE: thin cell
  replace taks_sd_min_read_quintile = . if grade == 4 & year == 2006   // YEAR HARDCODE: thin cell


  replace taks_sd_min_avg_quintile = . if grade < 3
  replace taks_sd_min_avg_quintile = . if grade == 3 & year == 2005   // YEAR HARDCODE: thin cell
  replace taks_sd_min_avg_quintile = . if grade == 3 & year == 2006   // YEAR HARDCODE: thin cell
  replace taks_sd_min_avg_quintile = . if grade == 4 & year == 2006   // YEAR HARDCODE: thin cell



  * ---- Save baseline quintile lookup (input to quintile robustness, App Table 6) ----
  keep id grade year *quintile*
  sort id year
  save /work/i/imberman/imberman/pre_katrina_quintiles.dta, replace   // PATH: repoint to your local globals

