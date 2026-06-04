*===============================================================================
* FILE:     katrina_by_quartiles_lim_test_fullint_nolag.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Robustness/variant (Houston linear-in-means achievement test)
* PRODUCES: Combined MATH + READING "no-lag-interaction" driver for the Houston
*           linear-in-means tables (Table 4; Appendix Tables 9 & 10).
*
* PURPOSE:  Combined math + reading version of the LIM "limited test" (companion
*           to katrina_by_quartiles_lim_test_fullint.do). Uses i.campus dummies
*           and interacts controls with quartiles (_q2/_q3/_q4 block), but the
*           lagged baseline scores (ltaks_sd_min_*_*) enter only as level terms,
*           NOT quartile-interacted. Explicit first-stage regressions of each
*           quartile peer score on the evacuee-share instruments are printed,
*           then 2SLS with the cross-quartile equality (LIM) `test`.
*
* INPUTS:   hisd_data.dta, katrina_data.dta, pre_katrina_quartiles.dta,
*           katrina_peer.dta
* OUTPUTS:  katrina_peer.dta (intermediate); regression output to the log
*           (OLS / first-stage / 2SLS for math and reading, elem & midhigh)
*
* KEY STEPS:
*   - Build leave-out average peer score per campus x grade x year.
*   - Loop over grade groups (elem, midhigh); build pre-Katrina test-score lags.
*   - Merge in baseline achievement quartiles and peer scores.
*   - Build grade x year interactions and i.campus dummies.
*   - Interact controls and peer score/evacuee share with native quartiles.
*   - For math then reading: OLS, four explicit first stages, 2SLS, LIM test.
*
* HARDCODED YEARS / PATHS TO UPDATE FOR A NEW-YEARS REPLICATION:
*   - cd /work/i/imberman/imberman/  (absolute path; repoint to local globals)
*   - All using/save paths /work/i/imberman/imberman/*.dta (absolute paths)
*   - `l`lag'.year <= 2004` in the lag loop: 2004 = last pre-Katrina year.
*
* NOTE: Documentation comments only -- no executable code was modified.
*===============================================================================
**THIS ANALYSIS IS SIMILAR TO THAT DONE IN HOXBY AND WEINGARTH (2005) IN THAT IT INTERACTS THE FRACTION EVACUEE IN EACH QUARTILE BASED ON  2005 SCORE
*WITH THE QUARTILE OF THE NATIVE STUDENT IN 2004 - THIS WILL ALLOW US TO TEST FOR THE EXISTENCE OF BOUTIQUE/BAD-APPLE/SHINING-LIGHT MODELS

*UNRESTRICTED VALUE-ADDED REGRESSIONS

*INSTRUMENTS FOR AVG PEER SCORE WITH KATRINA SHARE --> TEST OF LIM MODEL

****FULLY INTERACTED QUARTILE MODELS****

clear
set mem 10g
set matsize 4000
set more off
set seed 150


***OPTIONS****


*REGRESSIONS

* ---- Working directory & clear stale output files ----
  cd /work/i/imberman/imberman/    // PATH: repoint to your local globals
  capture rm outreg_quartile_grade.txt
  capture rm outreg_quartile_grade.xls
  capture rm outreg_quartile_grade.xml


* ---- Build leave-out average peer score (campus x grade x year) ----
  *GENERATE AVERAGE PEER SCORE
  use hisd_data.dta, clear        // PATH: hisd_data master Houston file

  gen taks_sd_min_math_nomiss = taks_sd_min_math != .
  gen taks_sd_min_read_nomiss = taks_sd_min_read != .
  gen perc_attn_nomiss = perc_attn != .
  gen infractions_nomiss = infractions != .

  foreach var of varlist taks_sd_min_math taks_sd_min_read perc_attn infractions {
    egen `var'_sum = sum(`var'), by(campus grade year)
    egen `var'_num = sum(`var'_nomiss), by(campus grade year)
    gen `var'_peer = (`var'_sum - `var')/(`var'_num - 1) if `var' != .
  }
  keep id year *_peer
  sort id year
  save /work/i/imberman/imberman/katrina_peer.dta, replace   // PATH: intermediate peer-means file

* ---- Loop over the two grade groups (elem, midhigh) ----
*LOOP OVER GRADE LEVEL
foreach grade in "elem" "midhigh" {

  *INCREASE COUNTER FOR GRADELEVEL (1 = ELEM, 2 = MIDHIGH)
  local gradenum = `gradenum' + 1

* ---- Open student panel for this grade group ----
  *OPEN KATRINA DATA
  use /work/i/imberman/imberman/katrina_data.dta, clear   // PATH: student panel
  xtset id year


* ---- Build pre-Katrina lagged baseline scores (level controls below) ----
  *GENEARATE TEST SCORE LAGS FROM PRE-KATRINA YEARS
  foreach var of varlist taks_sd_min_math taks_sd_min_read perc_attn infractions {
  gen l`var' = .
  gen lagyears_`var' = .
  foreach lag of numlist 1/5 {
    // YEAR HARDCODE: 2004 = last pre-Katrina year; only lags from <=2004 are used
    replace lagyears_`var' = `lag' if l`var' == . & l`lag'.`var' != . & l`lag'.year <= 2004
    replace l`var' = l`lag'.`var' if l`var' == . & l`lag'.`var' != . & l`lag'.year <= 2004
  }
  tab lagyears_`var', gen(lagyears_`var'_)
  forvalues gap = 1/4 {
    gen l`var'_`gap' = lagyears_`var'_`gap'*l`var'
  }
  }


  *KEEP ONLY GRADE LEVEL BEING ANALYSED IN SAMPLE
  keep if `grade' == 1

  
* ---- Merge baseline achievement quartiles & peer scores ----
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
  // baseline achievement quartiles (pre-Katrina), used to split natives below
  merge id year using /work/i/imberman/imberman/pre_katrina_quartiles.dta, _merge(_mergequartile) nokeep   // PATH

  *MERGE IN PEER DATA
  sort id year
  merge id year using /work/i/imberman/imberman/katrina_peer.dta, _merge(_mergepeer) nokeep   // PATH


* ---- Grade x year interactions and campus fixed-effect dummies ----
  *GENERATE GRADE X YEAR INTERACTIONS AND SCHOOL DUMMIES
  xi i.grade*i.year i.campus

  *DISPLAY GRADE LEVEL IN LOG FILE
  di " "
  di "`grade'"
  di " "

  *COUNTER FOR DEPENDENT VARIABLE
  local depvarid 0

* ---- Build control x native-quartile interactions (_q2/_q3/_q4) ----
  foreach var of varlist  ltaks_sd_min_math_*  ltaks_sd_min_read_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* {
    gen `var'_q2 = `var'*(`var'_quartile == 2)
    gen `var'_q3 = `var'*(`var'_quartile == 3)
    gen `var'_q4 = `var'*(`var'_quartile == 4)
  }


* ---- Interact peer score & evacuee share with baseline achievement quartiles ----
  *INTERACT PEER ACHIVEMENT & EVAC SHARE W/ NATIVE QUARTILES
   foreach var of varlist taks_sd_min_math taks_sd_min_read {
      gen `var'_peer_Q1 = `var'_peer*(`var'_quartile == 1)
      gen `var'_peer_Q2 = `var'_peer*(`var'_quartile == 2)
      gen `var'_peer_Q3 = `var'_peer*(`var'_quartile == 3)
      gen `var'_peer_Q4 = `var'_peer*(`var'_quartile == 4)
  }
      gen katrina_frac_grade_math_Q1 = katrina_frac_grade*(taks_sd_min_math_quartile == 1)
      gen katrina_frac_grade_math_Q2 = katrina_frac_grade*(taks_sd_min_math_quartile == 2)
      gen katrina_frac_grade_math_Q3 = katrina_frac_grade*(taks_sd_min_math_quartile == 3)
      gen katrina_frac_grade_math_Q4 = katrina_frac_grade*(taks_sd_min_math_quartile == 4)

      gen katrina_frac_grade_read_Q1 = katrina_frac_grade*(taks_sd_min_read_quartile == 1)
      gen katrina_frac_grade_read_Q2 = katrina_frac_grade*(taks_sd_min_read_quartile == 2)
      gen katrina_frac_grade_read_Q3 = katrina_frac_grade*(taks_sd_min_read_quartile == 3)
      gen katrina_frac_grade_read_Q4 = katrina_frac_grade*(taks_sd_min_read_quartile == 4)

* ==== MATH dependent variable (lag enters as level term, NOT quartile-interacted) ====
	*MATH


        *QUARTILES

	*OLS  (math peer-score coefficients by native quartile)
	reg taks_sd_min_math taks_sd_min_math_peer_*  ltaks_sd_min_math_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I*, cluster(campus)

	*FIRST STAGE  (each quartile peer score on the evacuee-share instruments)
	reg taks_sd_min_math_peer_Q1 katrina_frac_grade_math_Q* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I*, cluster(campus)
	reg taks_sd_min_math_peer_Q2 katrina_frac_grade_math_Q* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I*, cluster(campus)
	reg taks_sd_min_math_peer_Q3 katrina_frac_grade_math_Q* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I*, cluster(campus)
	reg taks_sd_min_math_peer_Q4 katrina_frac_grade_math_Q* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I*, cluster(campus)

	*SECOND STAGE  (2SLS: peer score instrumented by evacuee share, by quartile; LIM test)
	ivreg taks_sd_min_math  (taks_sd_min_math_peer_Q* = katrina_frac_grade_math_Q*)  ltaks_sd_min_math_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I*, cluster(campus)
	test taks_sd_min_math_peer_Q1 = taks_sd_min_math_peer_Q2 = taks_sd_min_math_peer_Q3 = taks_sd_min_math_peer_Q4


        *QUARTILES FULLY INTERACTED



* ==== READING dependent variable (lag enters as level term, NOT quartile-interacted) ====
	*READ


	*OLS  (reading peer-score coefficients by native quartile)
	reg taks_sd_min_read taks_sd_min_read_peer_*  ltaks_sd_min_read_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I*, cluster(campus)

	*FIRST STAGE  (each quartile peer score on the evacuee-share instruments)
	reg taks_sd_min_read_peer_Q1 katrina_frac_grade_read_Q* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I*, cluster(campus)
	reg taks_sd_min_read_peer_Q2 katrina_frac_grade_read_Q* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I*, cluster(campus)
	reg taks_sd_min_read_peer_Q3 katrina_frac_grade_read_Q* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I*, cluster(campus)
	reg taks_sd_min_read_peer_Q4 katrina_frac_grade_read_Q* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I*, cluster(campus)

	*SECOND STAGE  (2SLS: peer score instrumented by evacuee share, by quartile; LIM test)
	ivreg taks_sd_min_read  (taks_sd_min_read_peer_Q* = katrina_frac_grade_read_Q*)  ltaks_sd_min_read_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I*, cluster(campus)
	test taks_sd_min_read_peer_Q1 = taks_sd_min_read_peer_Q2 = taks_sd_min_read_peer_Q3 = taks_sd_min_read_peer_Q4
  


*CLOSE GRADELEVEL LOOP
}


