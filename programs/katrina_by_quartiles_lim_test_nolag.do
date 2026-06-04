*===============================================================================
* FILE:     katrina_by_quartiles_lim_test_nolag.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Robustness/variant (Houston linear-in-means achievement test)
* PRODUCES: "No-lag-interaction" combined MATH + READING rows for the Houston
*           linear-in-means tables (Table 4; Appendix Tables 9 & 10).
*
* PURPOSE:  Combined math + reading LIM "limited test" that does NOT fully
*           interact the controls with quartiles. For each subject it runs:
*           (i) a pre-Katrina-only OLS (year <= 2004) and an all-year OLS of
*           outcome on the (uninteracted) average peer score; (ii) the first
*           stage and 2SLS of peer score on the evacuee grade share; then
*           (iii) the same OLS / first-stage / 2SLS by native pre-Katrina
*           quartile, with the cross-quartile equality (LIM) `test`. The lag
*           is used only as a sample restriction (ltaks_sd_min_* non-missing),
*           not as a quartile-interacted control.
*           NOTE: lines 160 and 182 have apparent copy-paste quirks (a doubled
*           `if` and a missing sample restriction); left unchanged as found.
*
* INPUTS:   hisd_data.dta, katrina_data.dta, pre_katrina_quartiles.dta,
*           katrina_peer.dta
* OUTPUTS:  katrina_peer.dta (intermediate); regression output to the log
*           (pre/all-year OLS, first-stage, 2SLS, by quartile; math & reading)
*
* KEY STEPS:
*   - Build leave-out average peer score per campus x grade x year.
*   - Loop over grade groups (elem, midhigh); build pre-Katrina test-score lags.
*   - Merge in baseline achievement quartiles and peer scores.
*   - Build grade x year interactions and i.campus dummies.
*   - Interact peer score & evacuee share with native quartiles.
*   - For math then reading: pooled and by-quartile OLS / first-stage / 2SLS.
*
* HARDCODED YEARS / PATHS TO UPDATE FOR A NEW-YEARS REPLICATION:
*   - cd /work/i/imberman/imberman/  (absolute path; repoint to local globals)
*   - All using/save paths /work/i/imberman/imberman/*.dta (absolute paths)
*   - `l`lag'.year <= 2004` in the lag loop: 2004 = last pre-Katrina year.
*   - `if year <= 2004` on the pre-Katrina-only OLS rows (math & reading).
*
* NOTE: Documentation comments only -- no executable code was modified.
*===============================================================================
**THIS ANALYSIS IS SIMILAR TO THAT DONE IN HOXBY AND WEINGARTH (2005) IN THAT IT INTERACTS THE FRACTION EVACUEE IN EACH QUARTILE BASED ON  2005 SCORE
*WITH THE QUARTILE OF THE NATIVE STUDENT IN 2004 - THIS WILL ALLOW US TO TEST FOR THE EXISTENCE OF BOUTIQUE/BAD-APPLE/SHINING-LIGHT MODELS

*UNRESTRICTED VALUE-ADDED REGRESSIONS

*INSTRUMENTS FOR AVG PEER SCORE WITH KATRINA SHARE --> TEST OF LIM MODEL



clear
set mem 3g
set matsize 2000
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


* ---- Build pre-Katrina lagged scores (used as sample restriction below) ----
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

* ---- Pooled (no-quartile) LIM: pre-Katrina OLS, all-year OLS, first stage, 2SLS ----
        *NO QUARTILES

        *PRE KATRINA - OLS
	// YEAR HARDCODE: year <= 2004 restricts to pre-Katrina years only
	reg taks_sd_min_math taks_sd_min_math_peer  female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* if year <= 2004 & ltaks_sd_min_math != ., cluster(campus)

        *ALL YEAR - OLS
	reg taks_sd_min_math taks_sd_min_math_peer  female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* if  ltaks_sd_min_math != ., cluster(campus)

        *FIRST STAGE  (peer score on evacuee grade share)
	reg taks_sd_min_math_peer katrina_frac_grade  female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* if ltaks_sd_min_math != ., cluster(campus)

	*2SLS  (peer score instrumented by evacuee grade share)
	ivreg taks_sd_min_math (taks_sd_min_math_peer =  katrina_frac_grade)  female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* if  ltaks_sd_min_math != ., cluster(campus)

* ---- By-quartile LIM: OLS, four first stages, 2SLS, cross-quartile equality test ----
        *QUARTILES

	*OLS  (math peer-score coefficients by native quartile)
	reg taks_sd_min_math taks_sd_min_math_peer_*   female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I*  if  ltaks_sd_min_math != ., cluster(campus)
	test taks_sd_min_math_peer_Q1 = taks_sd_min_math_peer_Q2 = taks_sd_min_math_peer_Q3 = taks_sd_min_math_peer_Q4

	*FIRST STAGE
	reg taks_sd_min_math_peer_Q1 katrina_frac_grade_math_Q* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I*  if  ltaks_sd_min_math != ., cluster(campus)
	reg taks_sd_min_math_peer_Q2 katrina_frac_grade_math_Q* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I*  if  ltaks_sd_min_math != ., cluster(campus)
	reg taks_sd_min_math_peer_Q3 katrina_frac_grade_math_Q* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I*  if  ltaks_sd_min_math != ., cluster(campus)
	reg taks_sd_min_math_peer_Q4 katrina_frac_grade_math_Q* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I*  if  ltaks_sd_min_math != ., cluster(campus)

	*SECOND STAGE
	ivreg taks_sd_min_math  (taks_sd_min_math_peer_Q* = katrina_frac_grade_math_Q*)   female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I*  if  ltaks_sd_min_math != ., cluster(campus)
	test taks_sd_min_math_peer_Q1 = taks_sd_min_math_peer_Q2 = taks_sd_min_math_peer_Q3 = taks_sd_min_math_peer_Q4


* ==== READING dependent variable ====
	*READ

* ---- Pooled (no-quartile) LIM: pre-Katrina OLS, all-year OLS, first stage, 2SLS ----
        *NO QUARTILES

        *PRE KATRINA - OLS
	// YEAR HARDCODE: year <= 2004 restricts to pre-Katrina years (note: doubled `if` as in original)
	reg taks_sd_min_read taks_sd_min_read_peer  female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* if year <= 2004  if  ltaks_sd_min_read != ., cluster(campus)

        *ALL YEAR - OLS
	reg taks_sd_min_read taks_sd_min_read_peer  female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I*  if  ltaks_sd_min_read != ., cluster(campus)

        *FIRST STAGE  (peer score on evacuee grade share)
	reg taks_sd_min_read_peer katrina_frac_grade  female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I*  if  ltaks_sd_min_read != ., cluster(campus)

	*2SLS  (peer score instrumented by evacuee grade share)
	ivreg taks_sd_min_read (taks_sd_min_read_peer =  katrina_frac_grade)  female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I*  if  ltaks_sd_min_read != ., cluster(campus)

* ---- By-quartile LIM: OLS, four first stages, 2SLS, cross-quartile equality test ----
	*OLS  (reading peer-score coefficients by native quartile)
	reg taks_sd_min_read taks_sd_min_read_peer_*   female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I*  if  ltaks_sd_min_read != ., cluster(campus)
	test taks_sd_min_read_peer_Q1 = taks_sd_min_read_peer_Q2 = taks_sd_min_read_peer_Q3 = taks_sd_min_read_peer_Q4

	*FIRST STAGE
	reg taks_sd_min_read_peer_Q1 katrina_frac_grade_read_Q* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I*  if  ltaks_sd_min_read != ., cluster(campus)
	reg taks_sd_min_read_peer_Q2 katrina_frac_grade_read_Q* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I*  if  ltaks_sd_min_read != ., cluster(campus)
	reg taks_sd_min_read_peer_Q3 katrina_frac_grade_read_Q* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I*  if  ltaks_sd_min_read != ., cluster(campus)
	reg taks_sd_min_read_peer_Q4 katrina_frac_grade_read_Q* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I*  if  ltaks_sd_min_read != ., cluster(campus)

	*SECOND STAGE
	ivreg taks_sd_min_read  (taks_sd_min_read_peer_Q* = katrina_frac_grade_read_Q*)   female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I*, cluster(campus)
	test taks_sd_min_read_peer_Q1 = taks_sd_min_read_peer_Q2 = taks_sd_min_read_peer_Q3 = taks_sd_min_read_peer_Q4
  


*CLOSE GRADELEVEL LOOP
}


