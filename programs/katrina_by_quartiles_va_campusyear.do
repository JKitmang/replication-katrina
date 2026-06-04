*===============================================================================
* FILE:     katrina_by_quartiles_va_campusyear.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Robustness/variant (Houston VA quartile peer-effects, campus x year FE)
* PRODUCES: Appendix Tables 4 & 5 (and App 41 behavior battery) - the
*           CAMPUS-x-YEAR FIXED-EFFECTS row of the Houston grade-level
*           achievement robustness battery (post-Katrina years only).
*
* PURPOSE:  Robustness check that restricts to POST-KATRINA years (year >= 2005)
*           and absorbs CAMPUS-x-YEAR fixed effects, so identification comes from
*           within-school within-year across-grade variation in the evacuee
*           share. Estimates the grade-level evacuee share (katrina_frac_grade)
*           effect on incumbent math/read scores, attendance and infractions,
*           pooled and within each pre-Katrina achievement quartile, for elem
*           and midhigh.
*
* INPUTS:   /work/i/imberman/imberman/katrina_data.dta  (student-year panel)
*           /work/i/imberman/imberman/pre_katrina_quartiles.dta (incumbent quartiles)
* OUTPUTS:  Regression output to the log (areg coefficients on katrina_frac_grade,
*           absorbing campusyear); feeds the campus x year FE row of App Tables 4/5.
*
* KEY STEPS:
*   - Loop over grade level (elem, midhigh).
*   - Build pre-Katrina test-score lags (lags <= 2004).
*   - Keep only post-Katrina years (year >= 2005).
*   - Merge incumbent pre-Katrina achievement quartiles.
*   - Build campusyear FE id; grade x year interactions.
*   - Pooled VA model and quartile-specific models, absorbing campusyear.
*
* HARDCODED YEARS / PATHS TO UPDATE FOR A NEW-YEARS REPLICATION:
*   - cd /work/i/imberman/imberman/ and use/merge absolute paths -> PATH.
*   - l`lag'.year <= 2004 (twice) -> YEAR HARDCODE: pre-Katrina lags only.
*   - keep if year >= 2005 -> YEAR HARDCODE: restricts to post-Katrina years
*     (first post-Katrina year = 2005-06); widen for new years.
*
* NOTE: Documentation comments only -- no executable code was modified.
*===============================================================================
**THIS ANALYSIS IS SIMILAR TO THAT DONE IN HOXBY AND WEINGARTH (2005) IN THAT IT INTERACTS THE FRACTION EVACUEE IN EACH QUARTILE BASED ON  2005 SCORE
*WITH THE QUARTILE OF THE NATIVE STUDENT IN 2004 - THIS WILL ALLOW US TO TEST FOR THE EXISTENCE OF BOUTIQUE/BAD-APPLE/SHINING-LIGHT MODELS

*UNRESTRICTED VALUE-ADDED REGRESSIONS

*CONDUCTS ANALYSIS THAT LIMITS TO POST-KATRINA YEARS AND ALLOWS FOR VARIATION ACROSS GRADES W/IN SCHOOLS


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

  * ---- Restrict to post-Katrina years (campus x year FE design) ----
  *KEEP ONLY POST-KATRINA YEARS
  keep if year >= 2005   // YEAR HARDCODE: post-Katrina years only (first = 2005-06); widen for new years


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

  *DISPLAY GRADE LEVEL IN LOG FILE
  di " "
  di "`grade'"
  di " "

  *COUNTER FOR DEPENDENT VARIABLE
  local depvarid 0

* ---- Build campus x year FE identifier ----
gen double campusyear = campus*1000000 + year*100

*GENERATE GRADE X YEAR INTERACTIONS AND SCHOOL DUMMIES
xi i.grade*i.year

* ---- Pooled VA model, absorbing campus x year FE (App Tables 4/5 campusyear pooled row) ----
*RUN LINEAR MODEL
  di ""
  di "POOLED LINEAR MODEL"
  di ""
  # delimit ;
  foreach var of varlist taks_sd_min_math taks_sd_min_read {;
	areg `var'  katrina_frac_grade  l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* if `var'_quartile !=., cluster(campus) absorb(campusyear);

  };
  foreach var of varlist perc_attn infractions {;
	areg `var'  katrina_frac_grade  l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* , cluster(campus) absorb(campusyear);

  };
  # delimit cr


 * ---- Re-estimate within each baseline achievement quartile, campusyear FE (App Tables 4/5 quartile rows) ----
 *LOOP OVER QUARTILES
 foreach quartile of numlist 1/4 {

  di ""
  di "QUARTILE `quartile'"
  di ""

  # delimit ;
  *LOOP OVER DEPENDENT VARIABLES;

     ***ALL KATRINA****;
    	
	foreach var of varlist taks_sd_min_math taks_sd_min_read {;
		areg `var' katrina_frac_grade  l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* 
			if `var'_quartile == `quartile', cluster(campus) absorb(campusyear);


	};



*CLOSE QUARTILE LOOP;
};



*CLOSE GRADELEVEL LOOP;
};



