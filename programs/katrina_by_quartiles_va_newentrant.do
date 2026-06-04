*===============================================================================
* FILE:     katrina_by_quartiles_va_newentrant.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Robustness/variant (Houston value-added quartile analysis)
* PRODUCES: "New entrant" robustness row for the Houston grade-level
*           achievement/behavior batteries (App Tables 4, 5 & 41).
*
* PURPOSE:  Re-estimates the Houston value-added quartile peer-effect
*           regressions allowing the evacuee-share effect to DIFFER for students
*           who newly entered their school (changed campus that year) vs.
*           continuing students. This checks whether peer effects are
*           confounded with selective student mobility/sorting across campuses.
*
* INPUTS:   /work/i/imberman/imberman/hisd_data.dta   (to flag new entrants)
*           /work/i/imberman/imberman/katrina_data.dta
*           /work/i/imberman/imberman/pre_katrina_quartiles.dta
* OUTPUTS:  /work/i/imberman/imberman/new_entrant.dta  (intermediate flag file)
*           Regression output to the log only.
*
* KEY STEPS:
*   - Build new_entrant flag (campus changed vs. prior year) and save it.
*   - Loop over grade band (elem / midhigh).
*   - Build pre-Katrina lagged controls; merge entrant flag and quartiles.
*   - Interact evacuee share with new_entrant.
*   - Run pooled value-added areg, then loop over quartiles 1-4.
*
* HARDCODED YEARS / PATHS TO UPDATE FOR A NEW-YEARS REPLICATION:
*   - cd /work/i/imberman/imberman/  (absolute working dir; repoint to globals)
*   - all use/merge/save paths /work/i/imberman/imberman/*.dta
*   - lag cutoff `l`lag'.year <= 2004` (last pre-Katrina year)
*
* NOTE: Documentation comments only — no executable code was modified.
*===============================================================================
**THIS ANALYSIS IS SIMILAR TO THAT DONE IN HOXBY AND WEINGARTH (2005) IN THAT IT INTERACTS THE FRACTION EVACUEE IN EACH QUARTILE BASED ON  2005 SCORE
*WITH THE QUARTILE OF THE NATIVE STUDENT IN 2004 - THIS WILL ALLOW US TO TEST FOR THE EXISTENCE OF BOUTIQUE/BAD-APPLE/SHINING-LIGHT MODELS

*UNRESTRICTED VALUE-ADDED REGRESSIONS


**********SEPARATE ESTIMATES FOR NEW ENTRANTS INTO SCHOOL**********

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


 * ---- Build NEW-ENTRANT flag: student's campus differs from prior year ----
 *GENERATE INDICATOR FOR NEW ENTRANT
  use /work/i/imberman/imberman/hisd_data.dta, clear   // PATH: repoint to your local globals
  xtset id year
  gen new_entrant = l.campus != campus
  keep id year new_entrant
  sort id year
  save /work/i/imberman/imberman/new_entrant.dta, replace   // PATH: intermediate file; repoint to your local globals


*LOOP OVER GRADE LEVEL
foreach grade in "elem" "midhigh"{

  *INCREASE COUNTER FOR GRADELEVEL (1 = ELEM, 2 = MIDHIGH)
  local gradenum = `gradenum' + 1

  * ---- Load Houston analysis panel & merge entrant flag ----
  *OPEN KATRINA DATA
  use /work/i/imberman/imberman/katrina_data.dta, clear   // PATH: repoint to your local globals
  xtset id year

  *MERGE IN NEW ENTRANT DATA
  merge id year using /work/i/imberman/imberman/new_entrant.dta, nokeep _merge(_mergenew)   // PATH: repoint to your local globals
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


  * ---- Evacuee share x new-entrant interaction term ----
  *INTERACT EVACUEE SHARE W/ NEW ENTRANTS
  gen katrina_frac_grade_new = new_entrant*katrina_frac_grade

*RUN LINEAR MODEL


  di ""
  di "POOLED LINEAR MODEL"
  di ""
  * ---- POOLED value-added with new-entrant interaction (all quartiles) ----
  # delimit ;
  foreach var of varlist taks_sd_min_math taks_sd_min_read {;
	areg `var'  katrina_frac_grade katrina_frac_grade_new new_entrant l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* if `var'_quartile != ., cluster(campus) absorb(campus);
  };
  foreach var of varlist  perc_attn infractions {;
	areg `var'  katrina_frac_grade katrina_frac_grade_new new_entrant l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* , cluster(campus) absorb(campus);
  };
  # delimit cr


 * ---- BY-QUARTILE value-added with new-entrant interaction ----
 *LOOP OVER QUARTILES
 foreach quartile of numlist 1/4 {

  di ""
  di "QUARTILE `quartile'"
  di ""

  # delimit ;
  *LOOP OVER DEPENDENT VARIABLES;

     ***ALL KATRINA****;
    	
	foreach var of varlist taks_sd_min_math taks_sd_min_read {;
		areg `var' katrina_frac_grade   katrina_frac_grade_new new_entrant l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* 
			if `var'_quartile == `quartile', cluster(campus) absorb(campus);

	};



*CLOSE QUARTILE LOOP;
};



*CLOSE GRADELEVEL LOOP;
};


