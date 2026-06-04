*===============================================================================
* FILE:     katrina_by_quartiles_va_scale.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Robustness/variant (Houston value-added quartile analysis)
* PRODUCES: "Raw scale score" robustness row for the Houston grade-level
*           achievement robustness battery (Appendix Tables 4 & 5 family).
*
* PURPOSE:  Re-estimates the Houston value-added quartile peer-effect
*           regressions using the RAW (unstandardized) TAKS scale scores
*           (taks_scale_min_*) as outcomes and lag controls instead of the
*           within-grade-year standardized scores. Confirms results are not an
*           artifact of the score-standardization step. Quartile membership is
*           still defined from the standardized score (taks_sd_min_*_quartile).
*
* INPUTS:   /work/i/imberman/imberman/katrina_data.dta
*           /work/i/imberman/imberman/pre_katrina_quartiles.dta
* OUTPUTS:  Regression output to the log only.
*
* KEY STEPS:
*   - Loop over grade band (elem / midhigh).
*   - Build pre-Katrina lagged controls on RAW SCALE scores.
*   - Merge in pre-Katrina achievement quartiles.
*   - Run pooled value-added areg, then loop over quartiles 1-4
*     (math/read scale-score outcomes).
*
* HARDCODED YEARS / PATHS TO UPDATE FOR A NEW-YEARS REPLICATION:
*   - cd /work/i/imberman/imberman/  (absolute working dir; repoint to globals)
*   - all use/merge paths /work/i/imberman/imberman/*.dta
*   - lag cutoff `l`lag'.year <= 2004` (last pre-Katrina year)
*
* NOTE: This variant deliberately AVOIDS the score-standardization that the
*       baseline uses (it regresses on raw scale scores); see SCORE-SCALE note
*       below. Documentation comments only — no executable code was modified.
*===============================================================================
**THIS ANALYSIS IS SIMILAR TO THAT DONE IN HOXBY AND WEINGARTH (2005) IN THAT IT INTERACTS THE FRACTION EVACUEE IN EACH QUARTILE BASED ON  2005 SCORE
*WITH THE QUARTILE OF THE NATIVE STUDENT IN 2004 - THIS WILL ALLOW US TO TEST FOR THE EXISTENCE OF BOUTIQUE/BAD-APPLE/SHINING-LIGHT MODELS

*UNRESTRICTED VALUE-ADDED REGRESSIONS

*USE UNSTANDARDIZED SCALE SCORES

clear
set mem 3g
set matsize 2000
set more off

***OPTIONS****


*REGRESSIONS


* ---- Working directory & clear stale output files ----
  cd /work/i/imberman/imberman/   // PATH: repoint to your local globals
  capture rm outreg_quartile.txt
  capture rm outreg_quartile.xls
  capture rm outreg_quartile.xml


*LOOP OVER GRADE LEVEL
foreach grade in "elem" "midhigh"{

  *INCREASE COUNTER FOR GRADELEVEL (1 = ELEM, 2 = MIDHIGH)
  local gradenum = `gradenum' + 1

  * ---- Load Houston analysis panel ----
  *OPEN KATRINA DATA
  use /work/i/imberman/imberman/katrina_data.dta, clear   // PATH: repoint to your local globals
  xtset id year


  * ---- Build pre-Katrina lagged controls on RAW SCALE scores (taks_scale_min_*) ----
  * SCORE-SCALE NOTE: this variant uses unstandardized scale scores rather than
  * the within-grade-year standardized scores used in the baseline.
  *GENEARATE TEST SCORE LAGS FROM PRE-KATRINA YEARS
  foreach var of varlist taks_scale_min_math taks_scale_min_read {
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


  * ---- Merge in BASELINE ACHIEVEMENT QUARTILES (from STANDARDIZED score) ----
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

  *

  * ---- Grade x year interactions and campus fixed effects ----
  *GENERATE GRADE X YEAR INTERACTIONS AND SCHOOL DUMMIES
  xi i.grade*i.year

  *DISPLAY GRADE LEVEL IN LOG FILE
  di " "
  di "`grade'"
  di " "

  *COUNTER FOR DEPENDENT VARIABLE
  local depvarid 0


capture rm katrina_by_quartiles_va.txt
capture rm katrina_by_quartiles_va.xml

*RUN LINEAR MODEL


  di ""
  di "POOLED LINEAR MODEL"
  di ""
  * ---- POOLED value-added regressions on raw scale scores (all quartiles) ----
  # delimit ;
  foreach var in "math" "read" {;
	areg taks_scale_min_`var'  katrina_frac_grade  ltaks_scale_min_`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* if taks_sd_min_`var' != . & taks_sd_min_`var'_quartile !=., cluster(campus) absorb(campus);
  };
  # delimit cr


 * ---- BY-QUARTILE value-added regressions on raw scale scores ----
 *LOOP OVER QUARTILES
 foreach quartile of numlist 1/4 {

  di ""
  di "QUARTILE `quartile'"
  di ""

  # delimit ;
  *LOOP OVER DEPENDENT VARIABLES;

     ***ALL KATRINA****;
    	
  foreach var in "math" "read" {;
	areg taks_scale_min_`var'  katrina_frac_grade  ltaks_scale_min_`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* 
			if taks_sd_min_`var' != . &  taks_sd_min_`var'_quartile == `quartile', cluster(campus) absorb(campus);

	};



  *CLOSE QUARTILE LOOP;
  };


*CLOSE GRADELEVEL LOOP;
};

