*===============================================================================
* FILE:     katrina_by_quartiles_testtaking.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Robustness/variant (Houston attrition / test-taking check)
* PRODUCES: Appendix Table 11 (alongside check_non_test_takers2).
*
* PURPOSE:  Selection/attrition check. Tests whether an incumbent's probability of
*           TAKING the TAKS (math AND read) is correlated with the grade- or
*           campus-level evacuee share, after conditioning on campus FE, grade*year,
*           and demographics. If evacuee share does not predict test-taking, the
*           achievement results are unlikely to be driven by differential test-taking.
*
* INPUTS:   /work/i/imberman/imberman/katrina_data.dta             (HISD panel)
*           /work/i/imberman/imberman/pre_katrina_quartiles.dta    (quartiles)
* OUTPUTS:  Regression output to log (outreg_quartile_grade.* removed up front;
*           the linear-probability estimates print to the log).
*
* KEY STEPS:
*   - cd to the project dir and delete stale outreg files.
*   - Loop over grade level (elem, midhigh); reload HISD panel.
*   - Restrict to TAKS-tested grades (3-11); build test_taker indicator.
*   - Merge baseline achievement quartiles; build grade*year + campus dummies.
*   - areg of test_taker on grade share and on campus share (campus FE).
*
* HARDCODED YEARS / PATHS TO UPDATE FOR A NEW-YEARS REPLICATION:
*   - keep if grade >= 3 & grade <= 11   (TAKS-tested grade range, not a year)
*   - Absolute path in cd /work/i/imberman/imberman/  and all use/merge paths.
*   - No explicit year filter, but the 0-evacuees-before-2005 structure is implicit
*     in katrina_data.dta and the pre_katrina_quartiles baseline.
*
* NOTE: Documentation comments only — no executable code was modified.
*===============================================================================
**THIS ANALYSIS IS SIMILAR TO THAT DONE IN HOXBY AND WEINGARTH (2005) IN THAT IT INTERACTS THE FRACTION EVACUEE IN EACH QUARTILE BASED ON  2005 SCORE
*WITH THE QUARTILE OF THE NATIVE STUDENT IN 2004 - THIS WILL ALLOW US TO TEST FOR THE EXISTENCE OF BOUTIQUE/BAD-APPLE/SHINING-LIGHT MODELS

*UNRESTRICTED VALUE-ADDED REGRESSIONS

*TESTS WHETHER THE LIKELIHOOD OF TAKING A TAKS EXAM IS CORRELATED WITH KATRINA-SHARE AFTER CONDITIONING ON SCHOOL FE, ETC.

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

  *KEEP ONLY GRADE LEVEL BEING ANALYSED IN SAMPLE
  keep if `grade' == 1

  *LIMIT TO TAKS GRADES
  keep if grade >= 3 & grade <= 11   // GRADE RANGE HARDCODE: TAKS-tested grades 3-11

  * ---- Outcome: did the student take BOTH the math and reading TAKS? ----
  *IDENTIFY IF STUDENT TAKES BOTH MATH & READING
  gen test_taker = taks_sd_min_math != . & taks_sd_min_read != .
  
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
  * ---- Linear-probability test-taking regressions: grade share, then campus share ----
  # delimit ;
  foreach var of varlist test_taker {;
	areg `var'  katrina_frac_grade   female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* , cluster(campus) absorb(campus);
	areg `var'  katrina_frac_campus   female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* , cluster(campus) absorb(campus);
  };


*CLOSE GRADELEVEL LOOP;
};


