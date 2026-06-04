*===============================================================================
* FILE:     katrina_by_quartiles_pre_katrina_ols.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Analysis (Houston / HISD) -- pre-Katrina OLS benchmark
* PRODUCES: The "pre-Katrina OLS" rows of Table 4 (and the linear-in-means
*           comparison they anchor).
*
* PURPOSE:  Runs OLS / linear-in-means peer-effect models on Houston data using
*           ONLY the pre-Katrina years. Builds leave-out average PEER scores
*           (math, reading, attendance, infractions) at campus x grade x year,
*           then regresses an incumbent's own outcome on those peer means,
*           interacting the evacuee-quartile share with the incumbent's own
*           pre-Katrina (2004) achievement quartile -- the Hoxby & Weingarth
*           (2005) "boutique / bad-apple / shining-light" test setup. Because it
*           uses only pre-treatment years it shows what naive (endogenous) OLS
*           peer-effect estimates look like, as a foil for the evacuee-based
*           quasi-experimental estimates.
*
* INPUTS:   hisd_data.dta ; katrina_data.dta  (under /work/i/imberman/imberman/)
* OUTPUTS:  katrina_peer.dta (leave-out peer means) ; regression output / outreg
*           tables (outreg_quartile_grade.*).
*
* KEY STEPS:
*   - Build leave-out peer means: (sum - own)/(n - 1) by campus x grade x year.
*   - Construct pre-Katrina (<=2004) score/attendance/infraction lags.
*   - Loop over grade level (elem, midhigh) and run the OLS quartile models.
*
* HARDCODED YEARS / PATHS TO UPDATE FOR A NEW-YEARS REPLICATION:
*   - cd /work/i/imberman/imberman/  and the hisd_data/katrina_data/katrina_peer
*     paths  -> repoint to your $work global.
*   - lag construction restricted to pre-Katrina with `l`lag'.year <= 2004`
*     (YEAR HARDCODE: pre-Katrina baseline year).
*   - quartile based on 2004 score; evacuee split on 2005 score.
*
* NOTE: Documentation comments only -- no executable code was modified.
*===============================================================================
**THIS ANALYSIS IS SIMILAR TO THAT DONE IN HOXBY AND WEINGARTH (2005) IN THAT IT INTERACTS THE FRACTION EVACUEE IN EACH QUARTILE BASED ON  2005 SCORE
*WITH THE QUARTILE OF THE NATIVE STUDENT IN 2004 - THIS WILL ALLOW US TO TEST FOR THE EXISTENCE OF BOUTIQUE/BAD-APPLE/SHINING-LIGHT MODELS

*UNRESTRICTED VALUE-ADDED REGRESSIONS

*RUNS OLS/LINEAR-IN-MEANS MODELS OF PEER-EFFECTS USING ONLY PRE-KATRINA YEARS



clear
set mem 3g
set matsize 2000
set more off

***OPTIONS****



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
  merge id year using /work/i/imberman/imberman/pre_katrina_quartiles_2003.dta, _merge(_mergequartile) nokeep

  *MERGE IN PEER DATA
  sort id year
  merge id year using /work/i/imberman/imberman/katrina_peer.dta, _merge(_mergepeer) nokeep

  *LIMIT TO PRE-KATRINA YEARS
  keep if year >= 2003 & year <= 2005

  *GENERATE GRADE X YEAR INTERACTIONS AND SCHOOL DUMMIES
  xi i.grade*i.year i.campus

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

  *FIRST STAGE
  # delimit ;
  foreach var of varlist taks_sd_min_math taks_sd_min_read {;

	reg `var' `var'_peer l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* if `var'_quartile != ., cluster(campus);

  };
  foreach var of varlist perc_attn infractions {;

	reg `var' `var'_peer l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* , cluster(campus);

  };
  # delimit cr


 *LOOP OVER QUARTILES
 foreach quartile of numlist 1/4 {
 
  di "" 
  di "QUARTILE `quartile'"
  di ""

  # delimit ;
  *LOOP OVER DEPENDENT VARIABLES;


  *FIRST STAGE
  # delimit ;
  foreach var of varlist taks_sd_min_math taks_sd_min_read {;

	reg `var' `var'_peer  l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* 
		if `var'_quartile == `quartile', cluster(campus);

  };

  



*CLOSE QUARTILE LOOP;
};



*CLOSE GRADELEVEL LOOP;
};


