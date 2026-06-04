*===============================================================================
* FILE:     katrina_by_quartiles_lim_test_fullint_math_temp.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Analysis (Houston / HISD) -- SCRATCH / temporary variant
* PRODUCES: No published table on its own. This is a working copy of the math
*           linear-in-means driver (katrina_by_quartiles_lim_test_fullint_math.do)
*           kept for development; results feed Table 4 / App Tables 9 & 10 only
*           via its non-temp sibling. Treat as auxiliary.
*
* PURPOSE:  Fully-interacted Houston linear-in-means peer-effects model for MATH:
*           builds leave-out average peer scores, INSTRUMENTS the endogenous peer
*           mean with the evacuee ("Katrina") quartile shares, and interacts with
*           the incumbent's own pre-Katrina (2004) achievement quartile -- the
*           Epple-Romano-style test of the linear-in-means model (Hoxby &
*           Weingarth boutique/bad-apple/shining-light setup).
*
* INPUTS:   hisd_data.dta ; katrina_data.dta  (under /work/i/imberman/imberman/)
* OUTPUTS:  intermediate peer files ; outreg_quartile_grade.* (scratch).
*
* HARDCODED YEARS / PATHS TO UPDATE FOR A NEW-YEARS REPLICATION:
*   - cd /work/i/imberman/imberman/ and all use/save paths -> repoint to $work.
*   - 2004 = pre-Katrina baseline quartile year; 2005 = evacuee split year.
*   - pre-Katrina lag cutoff (year <= 2004).
*
* NOTE: Documentation comments only -- no executable code was modified.
*       Prefer the non-"_temp" file for replication.
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

  cd /work/i/imberman/imberman/
  capture rm outreg_quartile_grade.txt
  capture rm outreg_quartile_grade.xls
  capture rm outreg_quartile_grade.xml


  *GENERATE AVERAGE PEER SCORE
  use hisd_data.dta, clear

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
  save /work/i/imberman/imberman/katrina_peer.dta, replace


*LOOP OVER GRADE LEVEL
foreach grade in "elem" "midhigh" {

  *INCREASE COUNTER FOR GRADELEVEL (1 = ELEM, 2 = MIDHIGH)
  local gradenum = `gradenum' + 1

  *OPEN KATRINA DATA
  use /work/i/imberman/imberman/katrina_data.dta, clear
  xtset id year


  *GENEARATE TEST SCORE LAGS FROM PRE-KATRINA YEARS
  foreach var of varlist taks_sd_min_math taks_sd_min_read perc_attn infractions {
  gen l`var' = .
  gen lagyears_`var' = .
  foreach lag of numlist 1/5 {
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
  merge id year using /work/i/imberman/imberman/pre_katrina_quartiles.dta, _merge(_mergequartile) nokeep

  *MERGE IN PEER DATA
  sort id year
  merge id year using /work/i/imberman/imberman/katrina_peer.dta, _merge(_mergepeer) nokeep


  *DISPLAY GRADE LEVEL IN LOG FILE
  di " "
  di "`grade'"
  di " "

  *COUNTER FOR DEPENDENT VARIABLE
  local depvarid 0


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

	*MATH


keep if ltaks_sd_min_math_1 != .

  *GENERATE GRADE X YEAR INTERACTIONS AND SCHOOL DUMMIES
  xi i.grade*i.year i.female i.ethnicity i.econdis, prefix(_k)



sort campus taks_sd_min_math_quartile
by campus taks_sd_min_math_quartile: center  taks_sd_min_math taks_sd_min_math_peer_*  _k*  katrina_frac_grade_math_Q* ltaks_sd_min_math_*, replace

foreach var of varlist   taks_sd_min_math taks_sd_min_math_peer_*  _k*  katrina_frac_grade_math_Q* ltaks_sd_min_math_* {
  replace `var' = c_`var'
}

local x 1
foreach var of varlist _k* ltaks_sd_min_math_* {
    local x = `x' + 1
    xi i.taks_sd_min_math_quartile*`var', prefix(_g`x')
}




        *QUARTILES

	*OLS
	reg taks_sd_min_math taks_sd_min_math_peer_* _k* ltaks_sd_min_math_* _g*, cluster(campus) nocons
	test taks_sd_min_math_peer_Q1 = taks_sd_min_math_peer_Q2 = taks_sd_min_math_peer_Q3 = taks_sd_min_math_peer_Q4

	*REDUCED FORM
	reg taks_sd_min_math katrina_frac_grade_math_Q*   _k*  ltaks_sd_min_math_*  _g* if taks_sd_min_math_peer_Q1 != ., cluster(campus) nocons
	test katrina_frac_grade_math_Q1 = katrina_frac_grade_math_Q2 = katrina_frac_grade_math_Q3 = katrina_frac_grade_math_Q4


	*SECOND STAGE
	ivreg taks_sd_min_math  (taks_sd_min_math_peer_Q* = katrina_frac_grade_math_Q*)  _k* ltaks_sd_min_math_* _g*, cluster(campus) nocons
	test taks_sd_min_math_peer_Q1 = taks_sd_min_math_peer_Q2 = taks_sd_min_math_peer_Q3 = taks_sd_min_math_peer_Q4



*CLOSE GRADELEVEL LOOP
}


