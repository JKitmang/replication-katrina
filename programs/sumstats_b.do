*===============================================================================
* FILE:     sumstats_b.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Analysis (summary statistics)
* PRODUCES: Table 1 and Appendix Table 2 -- Houston (HISD) descriptive
*           statistics for 2005-06: evacuees vs. native students, plus evacuee
*           shares and sample sizes (the "_b" companion to sumstats_houston).
*
* PURPOSE:  Loads the HISD master file with evacuees, builds pre-Katrina test/
*           attendance/discipline lags and pre-Katrina achievement quartiles,
*           then reports means of demographics, free/reduced lunch, evacuee
*           shares, scores, attendance and infractions for natives vs. evacuees
*           in 2005 -- unweighted, school-weighted (all), and school-weighted
*           (any-katrina). Also prints observation counts, school counts, and
*           the school-grade distribution of evacuee shares.
*
* INPUTS:   katrina_data_with_evacs.dta (in cd /work/i/imberman/imberman/)
*           /work/i/imberman/imberman/pre_katrina_quartiles.dta
* OUTPUTS:  Summary statistics printed to log (no dataset saved).
*
* KEY STEPS:
*   - Load HISD-with-evacuees; xtset; build lagged outcomes from pre-2005 years.
*   - Merge pre-Katrina quartiles; drop students with no campus.
*   - Loop sum's over variables for natives vs evacuees in 2005 (3 weightings).
*   - Tabulate observation counts and school counts by group/level.
*   - Collapse to school-grade for the evacuee-share distribution.
*
* HARDCODED YEARS / PATHS TO UPDATE FOR A NEW-YEARS REPLICATION:
*   - cd /work/i/imberman/imberman/ and pre_katrina_quartiles.dta path --
*     PATH: repoint to your local globals.
*   - l`lag'.year <= 2004 in the lag loop (lags must be pre-Katrina).
*   - All sum's conditioned on year == 2005 (the reported cross-section).
*
* NOTE: Documentation comments only -- no executable code was modified.
*===============================================================================
**SUMMARY STATISTICS FOR 2005-06***

clear
set mem 6g
set matsize 2000
set more off
cd /work/i/imberman/imberman/   // PATH: repoint to your local globals



* ---- Load HISD data with evacuees ----
*LOAD DATA
use katrina_data_with_evacs, clear
xtset id year

  * ---- Build pre-Katrina lagged outcomes (most recent lag with year<=2004) ----
  *GENEARATE TEST SCORE LAGS FROM PRE-KATRINA YEARS
  foreach var of varlist taks_sd_min_math taks_sd_min_read perc_attn infractions {
  gen l`var' = .
  gen lagyears_`var' = .
  foreach lag of numlist 1/5 {
    replace lagyears_`var' = `lag' if l`var' == . & l`lag'.`var' != . & l`lag'.year <= 2004   // YEAR HARDCODE: lag must be pre-Katrina (<=2004)
    replace l`var' = l`lag'.`var' if l`var' == . & l`lag'.`var' != . & l`lag'.year <= 2004     // YEAR HARDCODE: lag must be pre-Katrina (<=2004)
  }
  tab lagyears_`var', gen(lagyears_`var'_)
  forvalues gap = 1/4 {
    gen l`var'_`gap' = lagyears_`var'_`gap'*l`var'
  }
  }

  
  * ---- Merge in pre-Katrina (baseline) achievement quartiles ----
  *MERGE IN KATRINA MEDIAN DATA & QUARTILE DATA
  capture drop katrina*median*
  sort id year
  merge id year using /work/i/imberman/imberman/pre_katrina_quartiles.dta, _merge(_mergequartile) nokeep   // PATH: repoint -- baseline achievement quartiles

f

*DROP STUDENTS WITH NO SCHOOL LISTED
drop if campus == .


  *GENERATE RACE DUMMIES  (A VALUE OF 1 IS NATIVE AMERICAN BUT ONLY 1000 OBS OVER ALL YEARS)
  gen white = ethnicity_2 == 5 
  gen asian = ethnicity_2 == 2

gen free_redlunch = freelunch + redlunch

* ==== TABLE 1 / APP TABLE 2: HISD means, natives vs evacuees, 2005 ====
* UNWEIGHTED panel: for each variable, natives (katrina==0) then evacuees (==1).
# delimit ;
  foreach var of varlist female white hisp black asian free_redlunch atrisk katrina_frac_campus katrina_frac_grade
	taks_sd_min_math
	taks_sd_min_read
	perc_attn
	infrac {;

        sum `var' if katrina == 0 & year == 2005;   /* YEAR HARDCODE: reported year */
	sum `var' if katrina == 1 & year == 2005;   /* YEAR HARDCODE: reported year */
  };


  * ==== TABLE 1 / APP TABLE 2: SCHOOL-WEIGHTED (ALL) panel ====
  **SCHOOL WEIGHTED ALL;
  egen enrollment = sum(unit), by(campus year katrina);
  egen anykatrina = max(katrina), by(campus year);

  gen school_weight = 1/enrollment;
  foreach var of varlist female white hisp black asian free_redlunch atrisk katrina_frac_campus katrina_frac_grade
	taks_sd_min_math
	taks_sd_min_read
	perc_attn
	infrac {;

        sum `var' [aw = school_weight] if katrina == 0 & year == 2005;
	sum `var' [aw = school_weight] if katrina == 1 & year == 2005;
  };
 

 * ==== TABLE 1 / APP TABLE 2: SCHOOL-WEIGHTED (ANY-KATRINA schools) panel ====
 **SCHOOL WEIGHTED ANY KATRINA;
  foreach var of varlist female white hisp black asian free_redlunch atrisk katrina_frac_campus katrina_frac_grade
	taks_sd_min_math
	taks_sd_min_read
	perc_attn
	infrac {;

        sum `var' [aw = school_weight] if katrina == 0 & year == 2005 & anykatrina == 1;
	sum `var' [aw = school_weight] if katrina == 1 & year == 2005 & anykatrina == 1;
  };
 


# delimit cr

* ==== TABLE 1 / APP TABLE 2: observation counts (N) by group/level/outcome ====
* All counts conditioned on year==2005 implicitly via the analysis sample.
**OBSERVATION COUNTS

*NATIVES

*ELEM
tab year if grade <= 5 & infractions != . & linfractions != . & katrina == 0
tab year if grade <= 5 & taks_sd_min_math != . & ltaks_sd_min_math != . & taks_sd_min_math_quartile != .  & katrina == 0
tab year if grade <= 5 & taks_sd_min_read != . & ltaks_sd_min_read != . & taks_sd_min_read_quartile != .  & katrina == 0


*MIDHIGH
tab year if grade > 5 & infractions != . & linfractions != .  & katrina == 0
tab year if grade > 5 & taks_sd_min_math != . & ltaks_sd_min_math != . & taks_sd_min_math_quartile != .  & katrina == 0
tab year if grade > 5 & taks_sd_min_read != . & ltaks_sd_min_read != . & taks_sd_min_read_quartile != .  & katrina == 0



*EVACS

*ELEM
tab year if grade <= 5 & infractions != . & katrina == 1
tab year if grade <= 5 & taks_sd_min_math != .  & katrina == 1
tab year if grade <= 5 & taks_sd_min_read != . & katrina == 1


*MIDHIGH
tab year if grade > 5 & infractions != .  & katrina == 1
tab year if grade > 5 & taks_sd_min_math != . & katrina == 1
tab year if grade > 5 & taks_sd_min_read != . & katrina == 1

* ==== TABLE 1 / APP TABLE 2: number-of-schools rows ====
**COUNT # OF SCHOOLS
unique campus if katrina == 0 & year == 2005   // YEAR HARDCODE: reported year
unique campus if katrina == 1 & year == 2005   // YEAR HARDCODE: reported year

*# OF SCHOOLS W/ POSITIVE EVAC SHARE
unique campus if katrina == 0 & year == 2005 & katrina_frac_campus > 0   // YEAR HARDCODE: reported year
unique campus if katrina == 1 & year == 2005 & katrina_frac_campus > 0   // YEAR HARDCODE: reported year

* ==== TABLE 1 / APP TABLE 2: school-grade distribution of evacuee shares ====
***COLLAPSE TO SCHOOL-GRADE LEVEL
keep if taks_sd_min_math_quartile != .
keep if katrina == 0

collapse (mean) katrina_frac*, by(campus grade year)

 foreach var of varlist katrina_frac_campus katrina_frac_grade {

        sum `var' if year == 2005 & grade <= 5, detail   // YEAR HARDCODE: reported year; elementary
        sum `var' if year == 2005 & grade > 5, detail    // YEAR HARDCODE: reported year; mid/high
  }

