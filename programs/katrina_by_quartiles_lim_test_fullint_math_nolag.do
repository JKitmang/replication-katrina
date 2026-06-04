*===============================================================================
* FILE:     katrina_by_quartiles_lim_test_fullint_math_nolag.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Robustness/variant (Houston linear-in-means achievement test, MATH)
* PRODUCES: MATH "no-lag" robustness rows of the Houston linear-in-means tables
*           (Appendix Tables 9 & 10; companion to Table 4).
*
* PURPOSE:  Same "limited test" of the linear-in-means peer-effect model for
*           HISD incumbents' MATH achievement as fullint_math.do, but DROPS the
*           lagged baseline-score control (ltaks_sd_min_math_*) entirely. Peer
*           score (by native quartile) is instrumented with the evacuee share
*           (by quartile); the `test` commands check equality of the four
*           quartile-specific peer coefficients (the LIM restriction).
*           VARIANT: "_nolag" = lagged-score control omitted.
*
* INPUTS:   hisd_data.dta, katrina_data.dta, pre_katrina_quartiles.dta,
*           katrina_peer.dta
* OUTPUTS:  katrina_peer.dta (intermediate); regression output to the log
*           (OLS / reduced-form / 2SLS for elem and midhigh grade groups)
*
* KEY STEPS:
*   - Build leave-out average peer score per campus x grade x year.
*   - Loop over grade groups (elem, midhigh); build pre-Katrina test-score lags
*     (lags still built, but NOT used as controls in the regressions below).
*   - Merge in baseline achievement quartiles and peer scores.
*   - Interact peer score & evacuee share with native math quartiles.
*   - Within campus x quartile, center variables (NO lag terms in the list).
*   - Run OLS, reduced-form, and IV (2SLS) and test cross-quartile equality.
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
set maxvar 10000

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


* ---- Build pre-Katrina lagged scores (built but NOT used as controls here) ----
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

  // keep only natives with a non-missing lagged baseline math score (sample definition)
keep if ltaks_sd_min_math_1 != .

  *GENERATE GRADE X YEAR INTERACTIONS AND SCHOOL DUMMIES
  xi i.grade*i.year i.female i.ethnicity i.econdis, prefix(_k)


* ---- Within-campus x quartile centering (NO-LAG: no ltaks terms in list) ----
sort campus taks_sd_min_math_quartile
by campus taks_sd_min_math_quartile: center  taks_sd_min_math taks_sd_min_math_peer_*  _k*  katrina_frac_grade_math_Q* , replace

foreach var of varlist   taks_sd_min_math taks_sd_min_math_peer_*  _k*  katrina_frac_grade_math_Q*  {
  replace `var' = c_`var'
}

* ---- Fully interact each control with native math quartile (NO-LAG: _k* only) ----
local x 1
foreach var of varlist _k*  {
    local x = `x' + 1
    xi i.taks_sd_min_math_quartile*`var', prefix(_g`x')
}




* ---- Estimation: OLS / reduced-form / 2SLS (NO lagged-score control), LIM test ----
        *QUARTILES

	*OLS  (math peer-score coefficients by native quartile)
	reg taks_sd_min_math taks_sd_min_math_peer_* _k*  _g*, cluster(campus) nocons
	test taks_sd_min_math_peer_Q1 = taks_sd_min_math_peer_Q2 = taks_sd_min_math_peer_Q3 = taks_sd_min_math_peer_Q4

	*REDUCED FORM  (evacuee share by quartile -> outcome)
	reg taks_sd_min_math katrina_frac_grade_math_Q*   _k*    _g* if taks_sd_min_math_peer_Q1 != ., cluster(campus) nocons
	test katrina_frac_grade_math_Q1 = katrina_frac_grade_math_Q2 = katrina_frac_grade_math_Q3 = katrina_frac_grade_math_Q4


	*SECOND STAGE  (2SLS: peer score instrumented by evacuee share, by quartile)
	ivreg taks_sd_min_math  (taks_sd_min_math_peer_Q* = katrina_frac_grade_math_Q*)  _k*  _g*, cluster(campus) nocons
	test taks_sd_min_math_peer_Q1 = taks_sd_min_math_peer_Q2 = taks_sd_min_math_peer_Q3 = taks_sd_min_math_peer_Q4



*CLOSE GRADELEVEL LOOP
}


