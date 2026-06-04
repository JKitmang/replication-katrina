*===============================================================================
* FILE:     katrina_by_quartiles_attrition.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Robustness/variant (Houston attrition / imputation robustness)
* PRODUCES: Appendix Tables 4 & 5 (entry in the Houston grade-level achievement
*           spec/robustness battery).
*
* PURPOSE:  Bounds the achievement results against non-random test attrition.
*           Enrolled incumbents who are MISSING a TAKS score are imputed three ways
*           and the value-added quartile regressions are re-run for each:
*             Model 1: impute the grade-year MINIMUM score.
*             Model 2: impute the student's PRIOR-YEAR lagged score.
*             Model 3: impute the grade-year MEAN of bottom-quartile students.
*           Stable coefficients across imputations imply attrition is not driving results.
*
* INPUTS:   /work/i/imberman/imberman/katrina_data.dta             (HISD panel)
*           /work/i/imberman/imberman/pre_katrina_quartiles.dta    (quartiles)
* OUTPUTS:  temp.dta (working file in the project dir, reloaded per model)
*           Regression output to log (outreg_quartile_grade.* removed up front).
*
* KEY STEPS:
*   - cd to project dir; delete stale outreg files; loop over grade level.
*   - Build pre-Katrina test-score lags; compute grade-year min and bottom-quartile means.
*   - Restrict to TAKS grades/years; save temp.dta.
*   - Model 1 (min imputation): pooled + by-quartile areg with campus FE.
*   - Model 2 (lag imputation): reload temp, re-impute, rerun.
*   - Model 3 (bottom-quartile-mean imputation): reload temp, re-impute, rerun.
*
* HARDCODED YEARS / PATHS TO UPDATE FOR A NEW-YEARS REPLICATION:
*   - lag construction uses l`lag'.year <= 2004   (pre/at-treatment lag cap)
*   - drop if grade > 11 | grade < 4    (TAKS-tested grade range, not a year)
*   - drop if grade < 5 & year == 2006  (5th-grade test not given in 2006-07)
*   - drop if year < 2003               (first analysis year)
*   - Absolute path cd /work/i/imberman/imberman/  and all use/merge paths.
*
* NOTE: Documentation comments only — no executable code was modified.
*===============================================================================


*************** TESTS MODELS UNDER DIFFERENT ASSUMPTIONS OF STUDENTS WHO ARE ENROLLED BUT DO NOT TAKE AN EXAM****

clear
set mem 3g
set matsize 2000
set more off

***OPTIONS****


  * ---- Project dir + clear stale outreg files ----
  *PATH: repoint to your local globals.
  cd /work/i/imberman/imberman/
  capture rm outreg_quartile_grade.txt
  capture rm outreg_quartile_grade.xls
  capture rm outreg_quartile_grade.xml


*LOOP OVER GRADE LEVEL
foreach grade in "elem" "midhigh"{

  *INCREASE COUNTER FOR GRADELEVEL (1 = ELEM, 2 = MIDHIGH)
  local gradenum = `gradenum' + 1

  *OPEN KATRINA DATA
  use /work/i/imberman/imberman/katrina_data.dta, clear
  xtset id year

  * ---- Build pre-Katrina test-score lags (gap dummies x lagged score) ----
  *GENEARATE TEST SCORE LAGS FROM PRE-KATRINA YEARS
  foreach var of varlist taks_sd_min_math taks_sd_min_read perc_attn infractions {
  gen l`var' = .
  gen lagyears_`var' = .
  foreach lag of numlist 1/5 {
    replace lagyears_`var' = `lag' if l`var' == . & l`lag'.`var' != . & l`lag'.year <= 2004   // YEAR HARDCODE: only lags from years <=2004 (pre/at treatment)
    replace l`var' = l`lag'.`var' if l`var' == . & l`lag'.`var' != . & l`lag'.year <= 2004   // YEAR HARDCODE: lag source capped at 2004
  }
  tab lagyears_`var', gen(lagyears_`var'_)
  forvalues gap = 1/4 {
    gen l`var'_`gap' = lagyears_`var'_`gap'*l`var'
  }
  gen lag`var' = l.`var'
  }


  * ---- Imputation building blocks: grade-year minimum scores (Model 1) ----
  *GENERATE MINIMUM SCORES
  egen min_math = min(taks_sd_min_math), by(grade year)
  egen min_read = min(taks_sd_min_read), by(grade year)
	

  
  *MERGE IN KATRINA MEDIAN DATA & QUARTILE DATA
  capture drop katrina*median*
  /*
  sort campus year
  merge campus year using /work/i/imberman/imberman/katrina_medians.dta, _merge(_mergekatmedian) nokeep
  foreach var of varlist katrina_frac_* katrina_count_* {
    replace `var' = 0 if `var' == .
  }
  */
  sort id year
  *PATH: repoint to your local globals.   BASELINE ACHIEVEMENT QUARTILES merged here.
  merge id year using /work/i/imberman/imberman/pre_katrina_quartiles.dta, _merge(_mergequartile) nokeep


  * ---- Imputation building block: grade-year mean of bottom quartile (Model 3) ----
  *GENERATE MEAN OF BOTTOM QUARTILE
  xtset id year
  egen mean_math_Q1a = mean(taks_sd_min_math) if taks_sd_min_math_quartile == 1, by(grade year)
  egen mean_math_Q1 = max(mean_math_Q1a), by(grade year)

  egen mean_read_Q1a = mean(taks_sd_min_math) if taks_sd_min_math_quartile == 1, by(grade year)
  egen mean_read_Q1 = max(mean_read_Q1a), by(grade year)

  *KEEP ONLY GRADE LEVEL BEING ANALYSED IN SAMPLE
  keep if `grade' == 1
  

  *GENERATE GRADE X YEAR INTERACTIONS AND SCHOOL DUMMIES
  xi i.grade*i.year

  *DISPLAY GRADE LEVEL IN LOG FILE
  di " "
  di "`grade'"
  di " "

  *COUNTER FOR DEPENDENT VARIABLE
  local depvarid 0

keep if grade != .

* ---- Restrict to TAKS-tested grades/years, then snapshot to temp.dta ----
*DROP GRADES THAT ARE NOT TESTED & YEARS NOT COVERED
drop if grade > 11 | grade < 4   // GRADE RANGE HARDCODE: TAKS-tested grades 4-11
drop if grade < 5 & year == 2006   // YEAR HARDCODE: 5th-grade test not administered in 2006-07
drop if year < 2003   // YEAR HARDCODE: 2003 = first analysis year; widen for new years


save temp, replace


* ---- MODEL 1: impute grade-year MINIMUM score for missing test-takers ----
***MODEL ONE - ANY ENROLLED STUDENT WHO IS MISSING A TEST SCORE GETS THE MINIMUM SCORE IN THAT GRADE/YEAR

*RUN LINEAR MODEL
	replace taks_sd_min_math = min_math if taks_sd_min_math == .
	replace taks_sd_min_read = min_read if taks_sd_min_read == .


  di ""
  di "POOLED LINEAR MODEL"
  di ""
  # delimit ;
  foreach var of varlist taks_sd_min_math taks_sd_min_read {;
	areg `var'  katrina_frac_grade  l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* if `var'_quartile != ., cluster(campus) absorb(campus);
  };
  # delimit cr

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
			if `var'_quartile == `quartile', cluster(campus) absorb(campus);

	};



*CLOSE QUARTILE LOOP;
};
# delimit cr





* ---- MODEL 2: impute the student's PRIOR-YEAR lagged score ----
***MODEL TWO - ANY ENROLLED STUDENT WHO IS MISSING A TEST SCORE GETS THEIR PRIOR YEAR LAGGED SCORE
use temp, clear
xtset id year
replace taks_sd_min_math = lagtaks_sd_min_math if taks_sd_min_math == .
replace taks_sd_min_read = lagtaks_sd_min_read if taks_sd_min_read == .

*RUN LINEAR MODEL


  di ""
  di "POOLED LINEAR MODEL"
  di ""
  # delimit ;
  foreach var of varlist taks_sd_min_math taks_sd_min_read {;
	areg `var'  katrina_frac_grade  l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* if `var'_quartile != ., cluster(campus) absorb(campus);
  };
  # delimit cr;

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
			if `var'_quartile == `quartile', cluster(campus) absorb(campus);

	};



*CLOSE QUARTILE LOOP;
};
# delimit cr



* ---- MODEL 3: impute the grade-year MEAN of bottom-quartile students ----
***MODEL THREE - ANY ENROLLED STUDENT WHO IS MISSING A TEST SCORE GETS THE MEAN SCORE OF 1ST QUARTILE STUDENTS
use temp, clear

replace taks_sd_min_math = mean_math_Q1 if taks_sd_min_math == .
replace taks_sd_min_read = mean_read_Q1 if taks_sd_min_read == .

*RUN LINEAR MODEL


  di ""
  di "POOLED LINEAR MODEL"
  di ""
  # delimit ;
  foreach var of varlist taks_sd_min_math taks_sd_min_read {;
	areg `var'  katrina_frac_grade  l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* if `var'_quartile != ., cluster(campus) absorb(campus);
  };

 # delimit cr
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
			if `var'_quartile == `quartile', cluster(campus) absorb(campus);

	};



*CLOSE QUARTILE LOOP;
};



*CLOSE GRADELEVEL LOOP;
};
