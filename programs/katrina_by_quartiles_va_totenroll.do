*===============================================================================
* FILE:     katrina_by_quartiles_va_totenroll.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Robustness/variant (Houston value-added quartile analysis)
* PRODUCES: "Evacuee count + enrollment control" robustness row for the Houston
*           grade-level achievement/behavior batteries (App Tables 4, 5 & 41).
*
* PURPOSE:  Re-estimates the Houston value-added quartile peer-effect
*           regressions using the EVACUEE COUNT (katrina_count_grade) as the
*           treatment instead of the evacuee SHARE, and controlling flexibly for
*           total grade enrollment with a 4th-order polynomial. This separates
*           the peer-composition effect from any pure class/grade-size effect.
*
* INPUTS:   /work/i/imberman/imberman/katrina_data.dta
*           /work/i/imberman/imberman/pre_katrina_quartiles.dta
* OUTPUTS:  Regression output to the log only.
*
* KEY STEPS:
*   - Loop over grade band (elem / midhigh).
*   - Build pre-Katrina lagged controls.
*   - Merge in pre-Katrina achievement quartiles.
*   - Build enrollment polynomial terms (enroll_grade_1 .. _4).
*   - Run pooled value-added areg on evacuee COUNT + enrollment poly, then
*     loop over quartiles 1-4.
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

***USES EVACUEE COUNTS WITH TOTAL ENROLLMENT AS CONTROL***


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


  * ---- Merge in BASELINE ACHIEVEMENT QUARTILES (incumbent pre-Katrina quartile) ----
  *MERGE IN KATRINA MEDIAN DATA & QUARTILE DATA
  capture drop katrina*median*
  /*
  sort campus year
  merge campus year using /work/i/imberman/imberman/katrina_medians.dta, _merge(_mergekatmedian) nokeep   // PATH (commented out)
  foreach var of varlist katrina_frac_* katrina_count_* {
    replace `var' = 0 if `var' == .
  }
  */
  sort id year
  merge id year using /work/i/imberman/imberman/pre_katrina_quartiles.dta, _merge(_mergequartile) nokeep   // PATH: repoint to your local globals; supplies *_quartile


  * ---- Grade x year interactions and campus fixed effects ----
  *GENERATE GRADE X YEAR INTERACTIONS AND SCHOOL DUMMIES
  xi i.grade*i.year

  *DISPLAY GRADE LEVEL IN LOG FILE
  di " "
  di "`grade'"
  di " "

  *COUNTER FOR DEPENDENT VARIABLE
  local depvarid 0

* ---- Total-enrollment polynomial controls (level, square, cube, quartic) ----
gen enroll_grade_1 = enroll_grade
gen enroll_grade_2 = enroll_grade^2
gen enroll_grade_3 = enroll_grade^3
gen enroll_grade_4 = enroll_grade^4


*RUN LINEAR MODEL


  di ""
  di "POOLED LINEAR MODEL"
  di ""
  * ---- POOLED value-added on evacuee COUNT + enrollment poly (all quartiles) ----
  # delimit ;
  foreach var of varlist taks_sd_min_math taks_sd_min_read {;
	areg `var'  katrina_count_grade  l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* enroll_grade_* if `var'_quartile != ., cluster(campus) absorb(campus);
  };
  foreach var of varlist  perc_attn infractions {;
	areg `var'  katrina_count_grade  l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* enroll_grade_*, cluster(campus) absorb(campus);
  };
  # delimit cr



 * ---- BY-QUARTILE value-added on evacuee COUNT + enrollment poly ----
 *LOOP OVER QUARTILES
 foreach quartile of numlist 1/4 {

  di ""
  di "QUARTILE `quartile'"
  di ""

  # delimit ;
  *LOOP OVER DEPENDENT VARIABLES;

     ***ALL KATRINA****;
    	
	foreach var of varlist taks_sd_min_math taks_sd_min_read {;
		areg `var' katrina_count_grade  l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* enroll_grade_*
			if `var'_quartile == `quartile', cluster(campus) absorb(campus);

	};



*CLOSE QUARTILE LOOP;
};



*CLOSE GRADELEVEL LOOP;
};



