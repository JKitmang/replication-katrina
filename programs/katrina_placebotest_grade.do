*===============================================================================
* FILE:     katrina_placebotest_grade.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Robustness/variant (Houston placebo test, GRADE-level share)
* PRODUCES: Placebo columns of Table 3 (grade-level evacuee share specification).
*
* PURPOSE:  Falsification test (grade-level companion to katrina_placebotest_c.do):
*           assigns each campus's ACTUAL 2005-06 GRADE-level evacuee share to the
*           pre-Katrina years (2003-04 & 2004-05) and re-runs the value-added
*           regressions. A significant "effect" in years with no evacuees would
*           indicate the share proxies pre-existing trends rather than a peer effect.
*
* INPUTS:   /work/i/imberman/imberman/katrina_data.dta             (HISD panel)
*           /work/i/imberman/imberman/pre_katrina_quartiles_placebo.dta (quartiles)
* OUTPUTS:  /work/i/imberman/imberman/temp.dta  (intermediate: 2005 grade shares)
*           Regression output to log (no table file written here).
*
* KEY STEPS:
*   - Collapse 2005 data to campus-mean grade evacuee share -> temp.dta.
*   - Loop over grade level (elem, midhigh); rebuild pre-Katrina test-score lags.
*   - Keep only 2003-04 & 2004-05; merge the 2005 grade share onto those years.
*   - Zero the placebo share in 2003; merge baseline quartiles; areg w/ campus FE.
*   - Run pooled outcomes, then split by pre-Katrina achievement quartile.
*
* HARDCODED YEARS / PATHS TO UPDATE FOR A NEW-YEARS REPLICATION:
*   - keep if year == 2005                (year the actual evacuee share is drawn from)
*   - lag construction uses l`lag'.year <= 2003   (cap on which years feed lags)
*   - keep if year >= 2003 & year <= 2004 (the placebo / pre-treatment window)
*   - replace katrina_frac_grade = 0 if year == 2003  (placebo share zeroed in 2003)
*   - Absolute paths /work/i/imberman/imberman/...
*
* NOTE: Documentation comments only — no executable code was modified.
*===============================================================================
*RUNS PLACEBO TEST ON 03-04 AND 04-05 APPLYING 05-06 KATRINA COUNTS TO 04-05 DATA


clear
set mem 3g
set matsize 2000
set more off



* ---- Build the placebo share: actual 2005-06 grade-level evacuee share ----
*PATH: repoint to your local globals.
*LOAD HISD DATA
use /work/i/imberman/imberman/katrina_data, clear

*KEEP ONLY THOSE WHO HAVE GRADES LISTED AND THUS WERE ENROLLED IN LATE OCTOBER OF THE YEAR
drop if grade == .

*KEEP 2005 ONLY
keep if year == 2005   // YEAR HARDCODE: 2005-06 = treatment year; its actual grade evacuee share becomes the placebo share

collapse (mean) katrina_frac_grade, by(campus)
*PATH: repoint to your local globals.
save /work/i/imberman/imberman/temp.dta, replace

# delimit ;

*REGRESSIONS;

local gradenum 0;

*LOOP OVER GRADE LEVEL;
foreach grade in "elem"  "midhigh"{;

  *INCREASE COUNTER FOR GRADELEVEL (1 = ELEM, 2 = MIDHIGH);
  local gradenum = `gradenum' + 1;

  *OPEN KATRINA DATA;
  use /work/i/imberman/imberman/katrina_data.dta, clear;
  xtset id year;

  # delimit cr
  * ---- Build pre-Katrina test-score lags (gap dummies x lagged score) ----
  *GENEARATE TEST SCORE LAGS FROM PRE-KATRINA YEARS
  foreach var of varlist taks_sd_min_math taks_sd_min_read perc_attn infractions {
  gen l`var' = .
  gen lagyears_`var' = .
  foreach lag of numlist 1/5 {
    replace lagyears_`var' = `lag' if l`var' == . & l`lag'.`var' != . & l`lag'.year <= 2003   // YEAR HARDCODE: only use lags from years <=2003 (pre-treatment) for placebo
    replace l`var' = l`lag'.`var' if l`var' == . & l`lag'.`var' != . & l`lag'.year <= 2003   // YEAR HARDCODE: lag source capped at 2003
  }
  tab lagyears_`var', gen(lagyears_`var'_)
  forvalues gap = 1/4 {
    gen l`var'_`gap' = lagyears_`var'_`gap'*l`var'
  }
  }


  * ---- Restrict to the placebo (pre-treatment) window and attach placebo share ----
  *KEEP ONLY 2003-04 AND 2004-05
  keep if year >= 2003 & year <= 2004   // YEAR HARDCODE: placebo window = pre-Katrina years 2003-04 & 2004-05


  *MERGE IN KATRINA FRACTION DATA
  sort campus
  drop _merge
  drop katrina_frac_grade
  *PATH: repoint to your local globals.
  merge campus using /work/i/imberman/imberman/temp.dta, nokeep
  replace katrina_frac_grade = 0 if year == 2003   // YEAR HARDCODE: placebo share set to 0 in 2003; only 2004 carries the "as-if" 2005 share

  
  * ---- Merge baseline achievement quartiles (placebo version) ----
  *MERGE IN QUARTILE DATA
  capture drop katrina*median*
  sort id year
  *PATH: repoint to your local globals.
  merge id year using /work/i/imberman/imberman/pre_katrina_quartiles_placebo.dta, _merge(_mergequartile) nokeep
 
  
  *KEEP ONLY GRADE LEVEL BEING ANALYSED IN SAMPLE
  keep if `grade' == 1


  # delimit ;
  *GENERATE GRADE X YEAR INTERACTIONS AND SCHOOL DUMMIES;
  xi i.grade*i.year;

  *DISPLAY GRADE LEVEL IN LOG FILE;
  di " ";
  di "`grade'";
  di " ";

  *COUNTER FOR DEPENDENT VARIABLE;
  local depvarid 0;



  * ---- Pooled placebo regressions (campus FE); expect null coefficients ----
  *LOOP OVER DEPENDENT VARIABLES;
  foreach subject of varlist taks_sd_min_math taks_sd_min_read {;

	areg `subject' katrina_frac_grade l`subject'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* if `subject'_quartile != ., cluster(campus) absorb(campus);

  };
  foreach subject of varlist perc_attn infrac {;
    
	areg `subject' katrina_frac_grade l`subject'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I*, cluster(campus) absorb(campus);

  };

 * ---- Placebo regressions split by baseline achievement quartile ----
 *LOOP OVER QUARTILES;
 foreach quartile of numlist 1/4 {;

  di "" ;
  di "QUARTILE `quartile'";
  di "";

	foreach var of varlist taks_sd_min_math taks_sd_min_read {;
		areg `var' katrina_frac_grade  l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* 
			if `var'_quartile == `quartile', cluster(campus) absorb(campus);
	};

  *CLOSE QUARTILE LOOP;
  };


*CLOSE GRADELEVEL LOOP;
};
