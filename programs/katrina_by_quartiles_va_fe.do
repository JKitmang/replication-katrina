*===============================================================================
* FILE:     katrina_by_quartiles_va_fe.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Robustness/variant (Houston VA quartile peer-effects, student FE)
* PRODUCES: Appendix Tables 4 & 5 (and App 41 behavior battery) - the STUDENT
*           FIXED-EFFECTS row of the Houston grade-level achievement robustness
*           battery.
*
* PURPOSE:  Robustness check that replaces the school-FE areg specification with
*           a STUDENT fixed-effects panel estimator (xtreg ... fe, clustered on
*           campus). Estimates the grade-level evacuee share
*           (katrina_frac_grade) effect on incumbent math/read scores,
*           attendance and infractions, pooled and within each pre-Katrina
*           achievement quartile, for elem and midhigh. Adds explicit campus
*           dummies (xi i.campus) so the FE model still nets out school effects.
*
* INPUTS:   /work/i/imberman/imberman/katrina_data.dta  (student-year panel)
*           /work/i/imberman/imberman/pre_katrina_quartiles.dta (incumbent quartiles)
* OUTPUTS:  Regression output to the log (xtreg fe coefficients on
*           katrina_frac_grade); feeds the student-FE row of App Tables 4/5 (and
*           App 41).
*
* KEY STEPS:
*   - Loop over grade level (elem, midhigh); large memory (set mem 20g).
*   - Build pre-Katrina test-score lags (lags <= 2004).
*   - Merge incumbent pre-Katrina achievement quartiles.
*   - Grade x year + campus dummies (xi i.grade*i.year i.campus); compress.
*   - xtset id year; pooled student-FE VA model and quartile-specific FE models.
*
* HARDCODED YEARS / PATHS TO UPDATE FOR A NEW-YEARS REPLICATION:
*   - cd /work/i/imberman/imberman/ and use/merge absolute paths -> PATH.
*   - l`lag'.year <= 2004 (twice) -> YEAR HARDCODE: pre-Katrina lags only.
*
* NOTE: Documentation comments only -- no executable code was modified.
*===============================================================================
**THIS ANALYSIS IS SIMILAR TO THAT DONE IN HOXBY AND WEINGARTH (2005) IN THAT IT INTERACTS THE FRACTION EVACUEE IN EACH QUARTILE BASED ON  2005 SCORE
*WITH THE QUARTILE OF THE NATIVE STUDENT IN 2004 - THIS WILL ALLOW US TO TEST FOR THE EXISTENCE OF BOUTIQUE/BAD-APPLE/SHINING-LIGHT MODELS

*UNRESTRICTED VALUE-ADDED REGRESSIONS


clear
set mem 20g
set matsize 2000
set more off

***OPTIONS****


* ---- Working directory + clear stale outreg files ----
  cd /work/i/imberman/imberman/   // PATH: repoint to your local globals
  capture rm outreg_quartile_grade.txt
  capture rm outreg_quartile_grade.xls
  capture rm outreg_quartile_grade.xml


*LOOP OVER GRADE LEVEL
foreach grade in "elem" "midhigh"{

  *INCREASE COUNTER FOR GRADELEVEL (1 = ELEM, 2 = MIDHIGH)
  local gradenum = `gradenum' + 1

  *OPEN KATRINA DATA
  use /work/i/imberman/imberman/katrina_data.dta, clear   // PATH: repoint to your local globals
  xtset id year

  * ---- Build pre-Katrina test-score lags (value-added controls) ----
  *GENEARATE TEST SCORE LAGS FROM PRE-KATRINA YEARS
  foreach var of varlist taks_sd_min_math taks_sd_min_read perc_attn infractions {
  gen l`var' = .
  gen lagyears_`var' = .
  foreach lag of numlist 1/5 {
    replace lagyears_`var' = `lag' if l`var' == . & l`lag'.`var' != . & l`lag'.year <= 2004   // YEAR HARDCODE: pre-Katrina lags only (<=2004)
    replace l`var' = l`lag'.`var' if l`var' == . & l`lag'.`var' != . & l`lag'.year <= 2004   // YEAR HARDCODE: pre-Katrina lag (<=2004)
  }
  tab lagyears_`var', gen(lagyears_`var'_)
  forvalues gap = 1/4 {
    gen l`var'_`gap' = lagyears_`var'_`gap'*l`var'
  }
  }

  *KEEP ONLY GRADE LEVEL BEING ANALYSED IN SAMPLE
  keep if `grade' == 1
  
  
  *MERGE IN KATRINA MEDIAN DATA & QUARTILE DATA
  capture drop katrina*median*
  /*
  sort campus year
  merge campus year using /work/i/imberman/imberman/katrina_medians.dta, _merge(_mergekatmedian) nokeep
  foreach var of varlist katrina_frac_* katrina_count_* {
    replace `var' = 0 if `var' == .
  }
  */
  * ---- Merge incumbent pre-Katrina achievement quartiles (BASELINE ACHIEVEMENT QUARTILES) ----
  sort id year
  merge id year using /work/i/imberman/imberman/pre_katrina_quartiles.dta, _merge(_mergequartile) nokeep   // PATH: repoint to your local globals


  *GENERATE GRADE X YEAR INTERACTIONS AND SCHOOL DUMMIES
  xi i.grade*i.year i.campus

  *DISPLAY GRADE LEVEL IN LOG FILE
  di " "
  di "`grade'"
  di " "

  *COUNTER FOR DEPENDENT VARIABLE
  local depvarid 0



*RUN LINEAR MODEL
compress
xtset id year

  di ""
  di "POOLED LINEAR MODEL"
  di ""
  * ---- Pooled STUDENT-FE VA model (xtreg fe), grade evacuee share (App Tables 4/5 student-FE pooled row) ----
  # delimit ;
  foreach var of varlist taks_sd_min_math taks_sd_min_read {;
	xtreg `var'  katrina_frac_grade  l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* if `var'_quartile != ., cluster(campus) fe nonest;
  };
  foreach var of varlist  perc_attn infractions {;
	xtreg `var'  katrina_frac_grade  l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* , cluster(campus) fe nonest;
  };
  # delimit cr


 * ---- Re-estimate within each baseline achievement quartile (App Tables 4/5 student-FE quartile rows) ----
 *LOOP OVER QUARTILES
 foreach quartile of numlist 1/4 {

  di ""
  di "QUARTILE `quartile'"
  di ""

  # delimit ;
  *LOOP OVER DEPENDENT VARIABLES;

     ***ALL KATRINA****;
    	
	foreach var of varlist taks_sd_min_math taks_sd_min_read {;
		xtreg `var' katrina_frac_grade  l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* 
			if `var'_quartile == `quartile', cluster(campus) fe nonest;

	};



*CLOSE QUARTILE LOOP;
};



*CLOSE GRADELEVEL LOOP;
};

