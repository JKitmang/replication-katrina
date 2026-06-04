*===============================================================================
* FILE:     katrina_nonkatrina.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Analysis (reduced-form / difference-in-differences, Houston)
* PRODUCES: Table 2 -- OLS differences in outcomes between Katrina evacuees and
*           native (non-evacuee) students within the same HISD school.
*
* PURPOSE:  Estimates how evacuees differ from incumbents on test scores,
*           attendance, and infractions, controlling for demographics and
*           campus x grade x year fixed effects. For each grade level (elem,
*           midhigh) and outcome it runs three specifications: 2005 only, 2006
*           only, and the 2005->2006 change (first difference, the diff-in-diff
*           contrast). The by-gender and AA-only loops are commented out.
*
* INPUTS:   /work/i/imberman/imberman/katrina_data_with_evacs.dta
*           /work/i/imberman/imberman/pre_katrina_quartiles.dta
* OUTPUTS:  (Active path) regressions printed to log. The commented-out post
*           blocks would write /work/i/imberman/hisd/katrina/postfiles/
*           katrina_nonkatrina.dta / .dat (Table 2 source).
*
* KEY STEPS:
*   - Load HISD-with-evacuees; xtset; build pre-Katrina lags (year<=2004).
*   - Merge pre-Katrina (baseline) quartiles; drop students with no campus.
*   - Build grade x year and campus dummies.
*   - Loop over grade level x outcome: reg in 2005, 2006, and first-difference.
*
* HARDCODED YEARS / PATHS TO UPDATE FOR A NEW-YEARS REPLICATION:
*   - Absolute paths /work/i/imberman/imberman/... and the postfiles/ output
*     path at the bottom -- PATH: repoint to your local globals.
*   - l`lag'.year <= 2004 in the lag loop (lags must be pre-Katrina).
*   - year == 2005 / year == 2006 in each specification (the two post years).
*
* NOTE: Documentation comments only -- no executable code was modified.
*===============================================================================
*THIS FILE CONDUCTS BASELINE OLS REGRESSIONS OF TEST SCORE DIFFERENCES B/W KATRINA EVACUEES AND NON-EVACUEES IN THE SAME SCHOOL

 clear
 set mem 3g
 set matsize 2000
 set more off


* ---- Load HISD data with evacuees ----  PATH: repoint to your local globals
*LOAD HISD DATA
use /work/i/imberman/imberman/katrina_data_with_evacs, clear
xtset id year

  * ---- Build pre-Katrina lagged outcomes (most recent lag with year<=2004) ----
  *GENEARATE TEST SCORE LAGS FROM PRE-KATRINA YEARS
  foreach var of varlist taks_sd_min_math taks_sd_min_read perc_attn infractions {
  gen l`var' = .
  gen lagyears_`var' = .
  foreach lag of numlist 1/5 {
    replace lagyears_`var' = `lag' if l`var' == . & l`lag'.`var' != . & l`lag'.year <= 2004   // YEAR HARDCODE: lag must be pre-Katrina (<=2004)
    replace l`var' = l`lag'.`var' if l`var' == . & l`lag'.`var' != . & l`lag'.year <= 2004     // YEAR HARDCODE: lag must be pre-Katrina (<=2004)
  }
  tab lagyears_`var', gen(lagyears_`var'_)
  forvalues gap = 1/4 {
    gen l`var'_`gap' = lagyears_`var'_`gap'*l`var'
  }
  }

  
  * ---- Merge in pre-Katrina (baseline) achievement quartiles ----
  *MERGE IN KATRINA MEDIAN DATA & QUARTILE DATA
  capture drop katrina*median*
  sort id year
  merge id year using /work/i/imberman/imberman/pre_katrina_quartiles.dta, _merge(_mergequartile) nokeep   // PATH: repoint -- baseline achievement quartiles



*DROP STUDENTS WITH NO SCHOOL LISTED
drop if campus == .


* ---- Build grade x year and campus fixed-effect dummies ----
# delimit ;

xi i.grade*i.year i.campus;
xtset id year;

* ==== TABLE 2: evacuee-vs-native OLS, all students ====
* For each grade level (elem/midhigh) and outcome, three regs: 2005, 2006, and
* the 2005->2006 first difference (d.). Coefficient on `katrina` = the contrast.
***ALL STUDENTS***;
local type 1;
local gradelevel 0;

*CYCLE OVER GRADELEVELS;
foreach grade in "elem" "midhigh" {;
  local gradelevel = `gradelevel' + 1;
  local depvarid 0;


   *CYCLE OVER OUTCOMES;
   foreach depvar of varlist taks_sd_min_math taks_sd_min_read {;
     local depvarid = `depvarid' + 1;

      *2005 ONLY;

      di "grade `grade'";
      di "`depvar'";
      di "2005 only" ;
      reg `depvar' katrina  female ethnicit_2-ethnicit_5 econdis_2-econdis_4 _I*  if `grade' == 1 & year == 2005
	& (katrina == 1 | (katrina == 0 & l`depvar' != . & `depvar'_quartile != .)) , cluster(campus) ;   /* YEAR HARDCODE: 2005 = first post-Katrina year; TABLE 2 col */
      local regression 1;


      *2006 ONLY;
      di "grade `grade'";
      di "`depvar'";
      di "2006";
      reg `depvar' katrina  female ethnicit_2-ethnicit_5 econdis_2-econdis_4 _I*  if `grade' == 1 & year == 2006
	& (katrina == 1 | (katrina == 0 & l`depvar' != . & `depvar'_quartile != .)) , cluster(campus) ;   /* YEAR HARDCODE: 2006 = second post-Katrina year; TABLE 2 col */
      local regression 2;



      *CHANGE FROM 2005 TO 2006;
      di "grade `grade'";
      di "`depvar'";
      di "CHANGE";
      reg d.`depvar' katrina  female ethnicit_2-ethnicit_5 econdis_2-econdis_4 _I*  if `grade' == 1
	& (katrina == 1 | (katrina == 0 & l`depvar' != . & `depvar'_quartile != .)) , cluster(campus) ;   /* 2005->2006 first difference (diff-in-diff); TABLE 2 col */
      local regression 3;

   } ;




   * ---- TABLE 2: attendance & infractions outcomes (same 3-spec structure) ----
   *CYCLE OVER OUTCOMES;
   foreach depvar of varlist perc_attn infrac {;
     local depvarid = `depvarid' + 1;

      *2005 ONLY;

      di "grade `grade'";
      di "`depvar'";
      di "2005 only" ;
      reg `depvar' katrina  female ethnicit_2-ethnicit_5 econdis_2-econdis_4 _I*  if `grade' == 1 & year == 2005
	& (katrina == 1 | (katrina == 0 & l`depvar' != .)) , cluster(campus);   /* YEAR HARDCODE: 2005 first post year */
      local regression 1;


      *2006 ONLY;
      di "grade `grade'";
      di "`depvar'";
      di "2006";
      reg `depvar' katrina  female ethnicit_2-ethnicit_5 econdis_2-econdis_4 _I*  if `grade' == 1 & year == 2006
	& (katrina == 1 | (katrina == 0 & l`depvar' != .)) , cluster(campus);   /* YEAR HARDCODE: 2006 second post year */
      local regression 2;



      *CHANGE FROM 2005 TO 2006;
      di "grade `grade'";
      di "`depvar'";
      di "CHANGE";
      reg d.`depvar' katrina  female ethnicit_2-ethnicit_5 econdis_2-econdis_4 _I*  if `grade' == 1
	& (katrina == 1 | (katrina == 0 & l`depvar' != .)) , cluster(campus);   /* 2005->2006 first difference */
      local regression 3;

   } ;
};

* NOTE: the by-gender (boys/girls) and AA-only blocks below are commented out
* (wrapped in /* ... */). They mirror the all-students loop with female/ethnicity
* restrictions and post the katrina coefficients to the postfile.
/*
*** BY GENDER **
local gradelevel 0;

***BOYS***

*CYCLE OVER GRADELEVELS;
foreach grade in "elem" "midhigh" {;
  local gradelevel = `gradelevel' + 1;
  local depvarid 0;
  local type 2;

   *CYCLE OVER OUTCOMES;
   foreach depvar of varlist stanford_math_sd stanford_read_sd stanford_lang_sd taks_sd_min_math taks_sd_min_read perc_attn infrac substance crime fighting{;
     local depvarid = `depvarid' + 1;

      *2005 ONLY;

      di "grade `grade'";
      di "`depvar'";
      di "2005 only" ;
      reg `depvar' katrina  female ethnicit_2-ethnicit_5 econdis_2-econdis_4 _I*  if `grade' == 1 & year == 2005 & female == 0, cluster(campus);
      local regression 1;
      post katrina_nonkatrina (`type') (`gradelevel') (`regression') (`depvarid') (1) ("boys") ("`grade'") ("2005") 
	("`depvar'") ("") ("coef") (_b[katrina]) (_b[katrina]/_se[katrina]) (e(N));
      post katrina_nonkatrina (`type') (`gradelevel') (`regression') (`depvarid') (1) ("boys") ("`grade'") ("2005") 
	("`depvar'") ("") ("se") (_se[katrina]) (_b[katrina]/_se[katrina]) (e(N));


      *2006 ONLY;
      di "grade `grade'";
      di "`depvar'";
      di "2006";
      reg `depvar' katrina  female ethnicit_2-ethnicit_5 econdis_2-econdis_4 _I*  if `grade' == 1 & year == 2006 & female == 0, cluster(campus);
      local regression 2;
      post katrina_nonkatrina (`type') (`gradelevel') (`regression') (`depvarid') (1) ("boys") ("`grade'") ("2006") 
	("`depvar'") ("") ("coef") (_b[katrina]) (_b[katrina]/_se[katrina]) (e(N));
      post katrina_nonkatrina (`type') (`gradelevel') (`regression') (`depvarid') (1) ("boys") ("`grade'") ("2006") 
	("`depvar'") ("") ("se") (_se[katrina]) (_b[katrina]/_se[katrina]) (e(N));


      *CHANGE FROM 2005 TO 2006;
      di "grade `grade'";
      di "`depvar'";
      di "CHANGE";   
      reg d.`depvar' katrina  female ethnicit_2-ethnicit_5 econdis_2-econdis_4 _I*  if `grade' == 1 & female == 0, cluster(campus);
      local regression 3;
      post katrina_nonkatrina (`type') (`gradelevel') (`regression') (`depvarid') (1) ("boys") ("`grade'") ("change") 
	("`depvar'") ("") ("coef") (_b[katrina]) (_b[katrina]/_se[katrina]) (e(N));
      post katrina_nonkatrina (`type') (`gradelevel') (`regression') (`depvarid') (1) ("boys") ("`grade'") ("change") 
	("`depvar'") ("") ("se") (_se[katrina]) (_b[katrina]/_se[katrina]) (e(N));

   } ;
};



***GIRLS***
local gradelevel 0;

*CYCLE OVER GRADELEVELS;
foreach grade in "elem" "midhigh" {;
  local gradelevel = `gradelevel' + 1;
  local depvarid 0;
  local type 3;

   *CYCLE OVER OUTCOMES;
   foreach depvar of varlist taks_sd_min_math taks_sd_min_read perc_attn infrac substance crime fighting{;
     local depvarid = `depvarid' + 1;

      *2005 ONLY;

      di "grade `grade'";
      di "`depvar'";
      di "2005 only" ;
      reg `depvar' katrina  female ethnicit_2-ethnicit_5 econdis_2-econdis_4 _I*  if `grade' == 1 & year == 2005 & female == 1, cluster(campus);
      local regression 1;
      post katrina_nonkatrina (`type') (`gradelevel') (`regression') (`depvarid') (1) ("girls") ("`grade'") ("2005") 
	("`depvar'") ("") ("coef") (_b[katrina]) (_b[katrina]/_se[katrina]) (e(N));
      post katrina_nonkatrina (`type') (`gradelevel') (`regression') (`depvarid') (1) ("girls") ("`grade'") ("2005") 
	("`depvar'") ("") ("se") (_se[katrina]) (_b[katrina]/_se[katrina]) (e(N));


      *2006 ONLY;
      di "grade `grade'";
      di "`depvar'";
      di "2006";
      reg `depvar' katrina  female ethnicit_2-ethnicit_5 econdis_2-econdis_4 _I*  if `grade' == 1 & year == 2006 & female == 1, cluster(campus);
      local regression 2;
      post katrina_nonkatrina (`type') (`gradelevel') (`regression') (`depvarid') (1) ("girls") ("`grade'") ("2006") 
	("`depvar'") ("") ("coef") (_b[katrina]) (_b[katrina]/_se[katrina]) (e(N));
      post katrina_nonkatrina (`type') (`gradelevel') (`regression') (`depvarid') (1) ("girls") ("`grade'") ("2006") 
	("`depvar'") ("") ("se") (_se[katrina]) (_b[katrina]/_se[katrina]) (e(N));


      *CHANGE FROM 2005 TO 2006;
      di "grade `grade'";
      di "`depvar'";
      di "CHANGE";   
      reg d.`depvar' katrina  female ethnicit_2-ethnicit_5 econdis_2-econdis_4 _I*  if `grade' == 1 & female == 1, cluster(campus);
      local regression 3;
      post katrina_nonkatrina (`type') (`gradelevel') (`regression') (`depvarid') (1) ("girls") ("`grade'") ("change") 
	("`depvar'") ("") ("coef") (_b[katrina]) (_b[katrina]/_se[katrina]) (e(N));
      post katrina_nonkatrina (`type') (`gradelevel') (`regression') (`depvarid') (1) ("girls") ("`grade'") ("change") 
	("`depvar'") ("") ("se") (_se[katrina]) (_b[katrina]/_se[katrina]) (e(N));

   } ;
};


/*

***AA ONLY***;

keep if ethnicity == 3;
local type 2;
local gradelevel 0;
xi: i.grade*i.year i.campus;

*CYCLE OVER GRADELEVELS;
foreach grade in "elem" "midhigh" {;
local gradelevel = `gradelevel' + 1;
local depvarid 1;

   *CYCLE OVER OUTCOMES;
   foreach depvar of varlist stanford_math_sd stanford_read_sd stanford_lang_sd taks_sd_min_math taks_sd_min_read  perc_attn infrac substance crime fighting{;
     local depvarid = `depvarid' + 1;
     
      *2005 ONLY;

      di "grade `grade'";
      di "`depvar'";
      di "2005 only" ;
      reg `depvar' katrina  female ethnicit_2-ethnicit_5 econdis_2-econdis_4 _I*  if `grade' == 1 & year == 2005, cluster(campus);
      local regression 1;
      post katrina_nonkatrina (`type') (`gradelevel') (`regression') (`depvarid') (1) ("aa only") ("`grade'") ("2005") 
	("`depvar'") ("") ("coef") (_b[katrina]) (_b[katrina]/_se[katrina]) (e(N));
      post katrina_nonkatrina (`type') (`gradelevel') (`regression') (`depvarid') (1) ("aa only") ("`grade'") ("2005") 
	("`depvar'") ("") ("se") (_se[katrina]) (_b[katrina]/_se[katrina]) (e(N));


      *2006 ONLY;
      di "grade `grade'";
      di "`depvar'";
      di "2006";
      reg `depvar' katrina  female ethnicit_2-ethnicit_5 econdis_2-econdis_4 _I*  if `grade' == 1 & year == 2006, cluster(campus);
      local regression 2;
      post katrina_nonkatrina (`type') (`gradelevel') (`regression') (`depvarid') (1) ("aa only") ("`grade'") ("2006") 
	("`depvar'") ("") ("coef") (_b[katrina]) (_b[katrina]/_se[katrina]) (e(N));
      post katrina_nonkatrina (`type') (`gradelevel') (`regression') (`depvarid') (1) ("aa only") ("`grade'") ("2006") 
	("`depvar'") ("") ("se") (_se[katrina]) (_b[katrina]/_se[katrina]) (e(N));


      *CHANGE FROM 2005 TO 2006;
      di "grade `grade'";
      di "`depvar'";
      di "CHANGE";   
      reg d.`depvar' katrina  female ethnicit_2-ethnicit_5 econdis_2-econdis_4 _I*  if `grade' == 1, cluster(campus);
      local regression 3;
      post katrina_nonkatrina (`type') (`gradelevel') (`regression') (`depvarid') (1) ("aa only") ("`grade'") ("change") 
	("`depvar'") ("") ("coef") (_b[katrina]) (_b[katrina]/_se[katrina]) (e(N));
      post katrina_nonkatrina (`type') (`gradelevel') (`regression') (`depvarid') (1) ("aa only") ("`grade'") ("change") 
	("`depvar'") ("") ("se") (_se[katrina]) (_b[katrina]/_se[katrina]) (e(N));

   } ;
};
*/

* ---- Write out the assembled Table 2 results file ----
postclose katrina_nonkatrina;
use /work/i/imberman/hisd/katrina/postfiles/katrina_nonkatrina.dta, clear;   // PATH: repoint
sort type  depvarid gradelevel reg statname;
outsheet using /work/i/imberman/hisd/katrina/postfiles/katrina_nonkatrina.dat, replace;   // PATH: repoint -- TABLE 2 output