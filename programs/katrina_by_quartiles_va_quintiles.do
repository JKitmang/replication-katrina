*===============================================================================
* FILE:     katrina_by_quartiles_va_quintiles.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Robustness/variant (Houston value-added quartile analysis)
* PRODUCES: Appendix Table 6 — the Houston value-added peer-effect estimates
*           sorted into pre-Katrina achievement QUINTILES (instead of quartiles).
*
* PURPOSE:  Re-estimates the by-group Houston value-added peer-effect
*           regressions using five pre-Katrina achievement QUINTILES rather than
*           four quartiles, to show the heterogeneity pattern is robust to a
*           finer partition of incumbent baseline achievement.
*
* INPUTS:   /work/i/imberman/imberman/katrina_data.dta
*           /work/i/imberman/imberman/pre_katrina_quintiles.dta (quintile sort)
* OUTPUTS:  Regression output to the log only.
*
* KEY STEPS:
*   - Loop over grade band (elem / midhigh).
*   - Build pre-Katrina lagged controls.
*   - Merge in pre-Katrina achievement QUINTILES.
*   - Loop over quintiles 1-5 running by-group value-added areg (no pooled
*     model in this variant).
*
* HARDCODED YEARS / PATHS TO UPDATE FOR A NEW-YEARS REPLICATION:
*   - cd /work/i/imberman/imberman/  (absolute working dir; repoint to globals)
*   - all use/merge paths /work/i/imberman/imberman/*.dta
*   - lag cutoff `l`lag'.year <= 2004` (last pre-Katrina year)
*
* NOTE: Documentation comments only — no executable code was modified.
*===============================================================================
**THIS ANALYSIS IS SIMILAR TO THAT DONE IN HOXBY AND WEINGARTH (2005) IN THAT IT INTERACTS THE FRACTION EVACUEE IN EACH QUARTILE BASED ON  2005 SCORE
*WITH THE QUARTILE OF THE NATIVE STUDENT IN 2004 - THIS WILL ALLOW US TO TEST FOR THE EXISTENCE OF BOUTIQUE/BAD-APPLE/SHINING-LIGHT MODELS

*UNRESTRICTED VALUE-ADDED REGRESSIONS

***USE QUINTILES INSTEEAD OF QUARTILES*

clear
set mem 3g
set matsize 2000
set more off

***OPTIONS****


* ---- Working directory & clear stale output files ----
  cd /work/i/imberman/imberman/   // PATH: repoint to your local globals
  capture rm outreg_quartile_grade.txt
  capture rm outreg_quartile_grade.xls
  capture rm outreg_quartile_grade.xml


*LOOP OVER GRADE LEVEL
foreach grade in "elem" "midhigh"{

  *INCREASE COUNTER FOR GRADELEVEL (1 = ELEM, 2 = MIDHIGH)
  local gradenum = `gradenum' + 1

  * ---- Load Houston analysis panel ----
  *OPEN KATRINA DATA
  use /work/i/imberman/imberman/katrina_data.dta, clear   // PATH: repoint to your local globals
  xtset id year

  * ---- Build pre-Katrina lagged controls (value-added: nearest pre-2005 lag) ----
  *GENEARATE TEST SCORE LAGS FROM PRE-KATRINA YEARS
  foreach var of varlist taks_sd_min_math taks_sd_min_read perc_attn infractions {
  gen l`var' = .
  gen lagyears_`var' = .
  foreach lag of numlist 1/5 {
    replace lagyears_`var' = `lag' if l`var' == . & l`lag'.`var' != . & l`lag'.year <= 2004   // YEAR HARDCODE: 2004 = last pre-Katrina year
    replace l`var' = l`lag'.`var' if l`var' == . & l`lag'.`var' != . & l`lag'.year <= 2004     // YEAR HARDCODE: 2004 = last pre-Katrina year
  }
  tab lagyears_`var', gen(lagyears_`var'_)
  forvalues gap = 1/4 {
    gen l`var'_`gap' = lagyears_`var'_`gap'*l`var'
  }
  }

  *KEEP ONLY GRADE LEVEL BEING ANALYSED IN SAMPLE
  keep if `grade' == 1


  * ---- Merge in BASELINE ACHIEVEMENT QUINTILES (incumbent pre-Katrina quintile) ----
  *MERGE IN KATRINA MEDIAN DATA & QUINTILE DATA
  capture drop katrina*median*
  /*
  sort campus year
  merge campus year using /work/i/imberman/imberman/katrina_medians.dta, _merge(_mergekatmedian) nokeep   // PATH (commented out)
  foreach var of varlist katrina_frac_* katrina_count_* {
    replace `var' = 0 if `var' == .
  }
  */
  sort id year
  merge id year using /work/i/imberman/imberman/pre_katrina_quintiles.dta, _merge(_mergequintile) nokeep   // PATH: repoint to your local globals; supplies *_quintile


  * ---- Grade x year interactions and campus fixed effects ----
  *GENERATE GRADE X YEAR INTERACTIONS AND SCHOOL DUMMIES
  xi i.grade*i.year

  *DISPLAY GRADE LEVEL IN LOG FILE
  di " "
  di "`grade'"
  di " "

  *COUNTER FOR DEPENDENT VARIABLE
  local depvarid 0



 * ---- BY-QUINTILE value-added regressions (evacuee share x incumbent quintile) ----
 *LOOP OVER QUINTILES
 foreach quintile of numlist 1/5 {

  di ""
  di "QUINTILE `quintile'"
  di ""

  # delimit ;
  *LOOP OVER DEPENDENT VARIABLES;

     ***ALL KATRINA****;
    	
	foreach var of varlist taks_sd_min_math taks_sd_min_read {;
		areg `var' katrina_frac_grade  l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* 
			if `var'_quintile == `quintile', cluster(campus) absorb(campus);

	};



*CLOSE QUINTILE LOOP;
};



*CLOSE GRADELEVEL LOOP;
};



