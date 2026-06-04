*===============================================================================
* FILE:     quartile_data.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Dataset construction
* PRODUCES: Intermediate dataset pre_katrina_quartiles.dta (baseline achievement
*           quartiles merged into the Houston quartile/peer-structure analyses)
*
* PURPOSE:  Assigns each student to a PRE-KATRINA baseline achievement quartile
*           from their standardized TAKS math, reading, and math-read-average
*           scores. Uses the student's 2004 score (falling back to 2003 if 2004
*           is missing) as the baseline, then splits within grade x year into
*           quartiles. Quartiles are blanked for grade/year cells that lack a
*           critical mass of test-takers.
*
* INPUTS:   hisd_data.dta (master Houston panel from merge_c.do)
* OUTPUTS:  pre_katrina_quartiles.dta (id grade year + *quartile* vars)
*
* KEY STEPS:
*   - Build math-read average score
*   - For each subject, pull each student's per-year score (2003-2006)
*   - BASELINE ACHIEVEMENT QUARTILES: baseline = 2004 score (else 2003);
*     quantiles(4) within grade x year
*   - Blank quartiles for thin grade x year cells
*
* HARDCODED YEARS / PATHS TO UPDATE FOR A NEW-YEARS REPLICATION:
*   - use /work/i/imberman/imberman/hisd_data.dta                      (PATH)
*   - save /work/i/imberman/imberman/pre_katrina_quartiles.dta         (PATH)
*   - forvalues year = 2003/2006 (per-year score extraction)           (YEAR HARDCODE)
*   - baseline split = `var'_2004 then `var'_2003                      (YEAR HARDCODE)
*   - quartile blanking: grade 3 in 2005/2006, grade 4 in 2006         (YEAR HARDCODE)
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

  * ---- BASELINE ACHIEVEMENT QUARTILES: baseline = 2004 (else 2003), nq(4) by grade x year ----
  *IDENTIFY NATIVE STUDENTS' PRE-KATRINA QUARTILE
    foreach var of varlist taks_sd_min_math taks_sd_min_read taks_sd_min_avg{
	gen `var'_split = `var'_2004                        // YEAR HARDCODE: baseline score = 2004
	replace `var'_split = `var'_2003 if `var'_split == .  // YEAR HARDCODE: fall back to 2003
	bysort grade year: quantiles `var'_split , gen(`var'_quartile) nq(4) stable   // baseline achievement quartiles (4)
    }

  *SET TO MISSING FOR YEARS AND GRADES WITHOUT A CRITICAL MASS OF STUDENTS
  replace taks_sd_min_math_quartile = . if grade < 3
  replace taks_sd_min_math_quartile = . if grade == 3 & year == 2005   // YEAR HARDCODE: thin cell
  replace taks_sd_min_math_quartile = . if grade == 3 & year == 2006   // YEAR HARDCODE: thin cell
  replace taks_sd_min_math_quartile = . if grade == 4 & year == 2006   // YEAR HARDCODE: thin cell

  replace taks_sd_min_read_quartile = . if grade < 3
  replace taks_sd_min_read_quartile = . if grade == 3 & year == 2005   // YEAR HARDCODE: thin cell
  replace taks_sd_min_read_quartile = . if grade == 3 & year == 2006   // YEAR HARDCODE: thin cell
  replace taks_sd_min_read_quartile = . if grade == 4 & year == 2006   // YEAR HARDCODE: thin cell


  replace taks_sd_min_avg_quartile = . if grade < 3
  replace taks_sd_min_avg_quartile = . if grade == 3 & year == 2005   // YEAR HARDCODE: thin cell
  replace taks_sd_min_avg_quartile = . if grade == 3 & year == 2006   // YEAR HARDCODE: thin cell
  replace taks_sd_min_avg_quartile = . if grade == 4 & year == 2006   // YEAR HARDCODE: thin cell



  * ---- Save baseline quartile lookup (input to quartile analyses) ----
  keep id grade year *quartile*
  sort id year
  save /work/i/imberman/imberman/pre_katrina_quartiles.dta, replace   // PATH: repoint to your local globals

