*===============================================================================
* FILE:     katrina_by_quartiles_va_grade_altstd.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Robustness/variant (Houston VA quartile peer-effects, alt standardization)
* PRODUCES: Appendix Tables 4 & 5 (grade-level achievement robustness battery) -
*           the "alternative standardization" row.
*
* PURPOSE:  Robustness check on the Houston grade-level VA quartile results that
*           uses an ALTERNATIVE standardization of TAKS scores
*           (taks_sdalt_min_math / taks_sdalt_min_read, standardized using only
*           non-evacuees -- the alt_standardize_2 construction). Estimates the
*           grade-level evacuee share (katrina_frac_grade) effect on incumbent
*           math/read scores, attendance and infractions, pooled and within each
*           pre-Katrina achievement quartile, for elem and midhigh.
*
* INPUTS:   /work/i/imberman/imberman/katrina_data.dta  (must contain the
*           alt-standardized taks_sdalt_min_* variables)
*           /work/i/imberman/imberman/pre_katrina_quartiles.dta (incumbent quartiles)
* OUTPUTS:  Regression output to the log (areg coefficients on katrina_frac_grade);
*           feeds the alt-standardization row of App Tables 4 & 5.
*
* KEY STEPS:
*   - Loop over grade level (elem, midhigh).
*   - Build pre-Katrina lags of the alt-standardized scores (lags <= 2004).
*   - Merge incumbent pre-Katrina achievement quartiles.
*   - Grade x year interactions + school FE via areg.
*   - Pooled VA model and quartile-specific VA models for math/read
*     (+attendance, infractions).
*
* HARDCODED YEARS / PATHS TO UPDATE FOR A NEW-YEARS REPLICATION:
*   - cd /work/i/imberman/imberman/ and use/merge absolute paths -> PATH.
*   - l`lag'.year <= 2004 (twice) -> YEAR HARDCODE: pre-Katrina lags only.
*   - SCORE STANDARDIZATION: handled upstream (taks_sdalt_min_* come from the
*     alt_standardize_2 cleaning file); quartile membership uses within-HISD
*     taks_sd_min_*_quartile.
*
* NOTE: Documentation comments only -- no executable code was modified.
*===============================================================================
**THIS ANALYSIS IS SIMILAR TO THAT DONE IN HOXBY AND WEINGARTH (2005) IN THAT IT INTERACTS THE FRACTION EVACUEE IN EACH QUARTILE BASED ON  2005 SCORE
*WITH THE QUARTILE OF THE NATIVE STUDENT IN 2004 - THIS WILL ALLOW US TO TEST FOR THE EXISTENCE OF BOUTIQUE/BAD-APPLE/SHINING-LIGHT MODELS

*UNRESTRICTED VALUE-ADDED REGRESSIONS

***ALTERNATIVE STANDARDIZATION****

clear
set mem 3g
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

  * ---- Build pre-Katrina lags of the ALT-standardized scores (value-added controls) ----
  *GENEARATE TEST SCORE LAGS FROM PRE-KATRINA YEARS
  foreach var of varlist taks_sdalt_min_math taks_sdalt_min_read perc_attn infractions {
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
  xi i.grade*i.year

  *DISPLAY GRADE LEVEL IN LOG FILE
  di " "
  di "`grade'"
  di " "

  *COUNTER FOR DEPENDENT VARIABLE
  local depvarid 0



*RUN LINEAR MODEL


  di ""
  di "POOLED LINEAR MODEL"
  di ""
  * ---- Pooled VA model on alt-std scores, school FE (App Tables 4/5 pooled row) ----
  # delimit ;

	areg taks_sdalt_min_math  katrina_frac_grade  ltaks_sdalt_min_math_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* if taks_sd_min_math_quartile != ., cluster(campus) absorb(campus);

	areg taks_sdalt_min_read  katrina_frac_grade  ltaks_sdalt_min_read_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* if taks_sd_min_read_quartile != ., cluster(campus) absorb(campus);

  foreach var of varlist  perc_attn infractions {;
	areg `var'  katrina_frac_grade  l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* , cluster(campus) absorb(campus);
  };
  # delimit cr


 * ---- Re-estimate within each baseline achievement quartile (App Tables 4/5 quartile rows) ----
 *LOOP OVER QUARTILES
 foreach quartile of numlist 1/4 {

  di ""
  di "QUARTILE `quartile'"
  di ""

  # delimit ;
  *LOOP OVER DEPENDENT VARIABLES;

     ***ALL KATRINA****;
    	

		areg taks_sdalt_min_math katrina_frac_grade  ltaks_sdalt_min_math_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* 
			if taks_sd_min_math_quartile == `quartile', cluster(campus) absorb(campus);

		areg taks_sdalt_min_read katrina_frac_grade  ltaks_sdalt_min_read_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* 
			if taks_sd_min_read_quartile == `quartile', cluster(campus) absorb(campus);





*CLOSE QUARTILE LOOP;
};



*CLOSE GRADELEVEL LOOP;
};



