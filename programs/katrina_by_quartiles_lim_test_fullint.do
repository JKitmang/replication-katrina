*===============================================================================
* FILE:     katrina_by_quartiles_lim_test_fullint.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Analysis (Houston linear-in-means / Epple-Romano achievement test)
* PRODUCES: Combined MATH + READING driver for the Houston linear-in-means
*           tables (Table 4; Appendix Tables 9 & 10). Companion / combined
*           version of the separate *_math.do and *_read.do files.
*
* PURPOSE:  Runs the "limited test" of the linear-in-means peer-effect model for
*           HISD incumbents, for both math and reading in one pass. Average peer
*           score (overall and by native pre-Katrina quartile) is instrumented
*           with the evacuee (Katrina) grade share, also split by quartile. If
*           peer effects are linear-in-means, the four quartile-specific peer
*           coefficients are equal -- the `test` commands check this. This
*           variant uses i.campus dummies (not within-quartile centering) and
*           interacts the controls with quartiles via the _q2/_q3/_q4 block.
*
* INPUTS:   hisd_data.dta, katrina_data.dta, pre_katrina_quartiles.dta,
*           katrina_peer.dta
* OUTPUTS:  katrina_peer.dta (intermediate); regression output to the log
*           (OLS / 2SLS for math and reading, for elem and midhigh groups)
*
* KEY STEPS:
*   - Build leave-out average peer score per campus x grade x year.
*   - Loop over grade groups (elem, midhigh); build pre-Katrina test-score lags.
*   - Merge in baseline achievement quartiles and peer scores.
*   - Build grade x year interactions and i.campus dummies.
*   - Interact controls and peer score/evacuee share with native quartiles.
*   - Run OLS and 2SLS for math, then for reading; test cross-quartile equality.
*
* HARDCODED YEARS / PATHS TO UPDATE FOR A NEW-YEARS REPLICATION:
*   - cd /work/i/imberman/imberman/  (absolute path; repoint to local globals)
*   - All using/save paths /work/i/imberman/imberman/*.dta (absolute paths)
*   - `l`lag'.year <= 2004` in the lag loop: 2004 = last pre-Katrina year used
*     to source lagged baseline scores.
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


* ---- Build pre-Katrina lagged baseline scores (controls) ----
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

* ---- Fully interact every control with native baseline quartile (_q2/_q3/_q4) ----
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

* ==== MATH dependent variable ====
	*MATH

* ---- Estimation: OLS then 2SLS (peer score by quartile), with LIM equality test ----
        *QUARTILES

	*OLS  (math peer-score coefficients by native quartile)
	reg taks_sd_min_math taks_sd_min_math_peer_*  female* ethnicit_1* ethnicit_2* ethnicit_3* ethnicit_4* econdis_2* econdis_3* econdis_4* _I*, cluster(campus)

	*SECOND STAGE  (2SLS: peer score instrumented by evacuee share, by quartile)
	ivreg taks_sd_min_math  (taks_sd_min_math_peer_Q* = katrina_frac_grade_math_Q*)   female* ethnicit_1* ethnicit_2* ethnicit_3* ethnicit_4* econdis_2* econdis_3* econdis_4* _I*, cluster(campus)
	test taks_sd_min_math_peer_Q1 = taks_sd_min_math_peer_Q2 = taks_sd_min_math_peer_Q3 = taks_sd_min_math_peer_Q4


        *QUARTILES FULLY INTERACTED



* ==== READING dependent variable ====
	*READ

* ---- Estimation: OLS then 2SLS (peer score by quartile), with LIM equality test ----
	*OLS  (reading peer-score coefficients by native quartile)
	reg taks_sd_min_read taks_sd_min_read_peer_*  female* ethnicit_1* ethnicit_2* ethnicit_3* ethnicit_4* econdis_2* econdis_3* econdis_4* _I*, cluster(campus)

	*SECOND STAGE  (2SLS: peer score instrumented by evacuee share, by quartile)
	ivreg taks_sd_min_read  (taks_sd_min_read_peer_Q* = katrina_frac_grade_read_Q*)  female* ethnicit_1* ethnicit_2* ethnicit_3* ethnicit_4* econdis_2* econdis_3* econdis_4* _I*, cluster(campus)
	test taks_sd_min_read_peer_Q1 = taks_sd_min_read_peer_Q2 = taks_sd_min_read_peer_Q3 = taks_sd_min_read_peer_Q4
  


*CLOSE GRADELEVEL LOOP
}


