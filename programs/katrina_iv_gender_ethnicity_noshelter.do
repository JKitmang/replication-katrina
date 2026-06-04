*===============================================================================
* FILE:     katrina_iv_gender_ethnicity_noshelter.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Analysis (Houston peer-effect estimates by gender & race)
* PRODUCES: Appendix Table 3 -- HISD school-level evacuee-share peer effects on
*           native students, split by gender (male/female) and race (Black/
*           Hisp/White), for each grade level (elem, midhigh).
*
* PURPOSE:  Estimates how the SCHOOL-level evacuee share (katrina_frac_campus)
*           affects incumbents' standardized math/reading scores, attendance,
*           and infractions, with campus FE, grade x year FE, pre-Katrina lags,
*           and demographic controls, clustered by campus. Despite the file
*           header mentioning IV, the active specifications here are OLS (areg);
*           the "noshelter" label flags that the analysis is restricted to the
*           involuntary-assignment (zoned-school, non-shelter) logic underlying
*           the Sept-13-2005 instrument used elsewhere.
*
* INPUTS:   /work/i/imberman/imberman/katrina_data.dta
*           /work/i/imberman/imberman/pre_katrina_quartiles.dta
* OUTPUTS:  outreg_gender_ethnicity.xls/.txt/.xml (via outreg2) in
*           cd /work/i/imberman/imberman -- App Table 3 source. One column per
*           grade x subgroup x outcome (coefficient on katrina_frac_campus).
*
* KEY STEPS:
*   - Loop over grade level (elem/midhigh): load data, build pre-Katrina lags,
*     keep that grade level, merge baseline quartiles, build grade x year dummies.
*   - Inner loops over gender (0/1) then race (3/4/5) x outcome: areg with
*     campus FE; outreg2 the evacuee-share coefficient.
*
* HARDCODED YEARS / PATHS TO UPDATE FOR A NEW-YEARS REPLICATION:
*   - cd /work/i/imberman/imberman and the katrina_data / pre_katrina_quartiles
*     paths, plus the outreg_gender_ethnicity.* output files -- PATH: repoint.
*   - l`lag'.year <= 2004 in the lag loop (lags must be pre-Katrina).
*
* NOTE: Documentation comments only -- no executable code was modified.
*===============================================================================
*RUNS FIRST-STAGE & REDUCED FORM REGRESSIONS USING VARIOUS INSTRUMENT CANDIDATES


clear
set mem 3g
set matsize 2000
set more off

*REGRESSIONS

*USE DELIMITER TO ALLOW COMMANDS TO SPREAD LINES
# delimit ;


*COUNTERS ALLOW ME TO GENERATE UNIQUE IDENTIFIERS FOR EACH REGRESSION THAT CAN LATER BE SORTED IN A WAY THAT IS EASILY TRANSFERABLE TO EXCEL DATA TABLES;
*COUNTER FOR GRADE LEVEL;
local gradenum 0;
 
cd /work/i/imberman/imberman;   /* PATH: repoint to your local globals */
capture rm outreg_gender_ethnicity.txt;
capture rm outreg_gender_ethnicity.xml;
capture rm outreg_gender_ethnicity.xls;


* ==== APP TABLE 3: loop over grade level (elem, midhigh) ====
*LOOP OVER GRADE LEVEL;
foreach grade in "elem" "midhigh"{;

  *INCREASE COUNTER FOR GRADELEVEL (1 = ELEM, 2 = MIDHIGH);
  local gradenum = `gradenum' + 1;

  *OPEN TEMPORARY DATAFILE SAVED EARLIER IN PROGRAM;
  use /work/i/imberman/imberman/katrina_data.dta, clear;   /* PATH: repoint */
  xtset id year;

  * ---- Build pre-Katrina lagged outcomes (most recent lag, year<=2004) ----
  *GENEARATE TEST SCORE LAGS FROM PRE-KATRINA YEARS;
  foreach var of varlist taks_sd_min_math taks_sd_min_read perc_attn infractions {;
  gen l`var' = .;
  gen lagyears_`var' = .;
  foreach lag of numlist 1/5 {;
    replace lagyears_`var' = `lag' if l`var' == . & l`lag'.`var' != . & l`lag'.year <= 2004;   /* YEAR HARDCODE: lag must be pre-Katrina (<=2004) */
    replace l`var' = l`lag'.`var' if l`var' == . & l`lag'.`var' != . & l`lag'.year <= 2004;     /* YEAR HARDCODE: lag must be pre-Katrina (<=2004) */
  };
  tab lagyears_`var', gen(lagyears_`var'_);
  forvalues gap = 1/4 {;
    gen l`var'_`gap' = lagyears_`var'_`gap'*l`var';
  };
  };

  *OPTION TO TAKE RANDOM SAMPLE FOR PROGRAM TESTING;
  *set seed 300083;
  *gsample 5, percent wor cluster(id);

  *KEEP ONLY GRADE LEVEL BEING ANALYSED IN SAMPLE;
  keep if `grade' == 1;

  * ---- Merge in pre-Katrina (baseline) achievement quartiles ----
  *MERGE IN KATRINA MEDIAN DATA & QUARTILE DATA;
  capture drop katrina*median*;
  sort id year;
  merge id year using /work/i/imberman/imberman/pre_katrina_quartiles.dta, _merge(_mergequartile) nokeep;   /* PATH: repoint -- baseline achievement quartiles */

  *GENERATE GRADE X YEAR INTERACTIONS AND SCHOOL DUMMIES;
  xi i.grade*i.year;

  *DISPLAY GRADE LEVEL IN LOG FILE;
  di " ";
  di "`grade'";
  di " ";

  *COUNTER FOR DEPENDENT VARIABLE;
  local depvarid 0;

* ==== APP TABLE 3: by-gender panels (0=male, 1=female) ====
* Each areg + outreg2 below writes one App Table 3 column: coefficient on
* katrina_frac_campus (school-level evacuee share) for the subgroup x outcome.
*LOOP OVER GENDER {;
forvalues gender = 0/1 {;

  *LOOP OVER DEPENDENT VARIABLES;
  foreach subject of varlist taks_sd_min_math taks_sd_min_read {;
    
	*INCREASE COUNTER FOR DEPENDENT VARIABLE;
	local depvarid = `depvarid' + 1;


	*OLS - LIMIT TO ZONED SCHOOLS B/C LEASEABLE SPACE ONLY APPLY TO ZONED SCHOOLS;
	*ALSO WHILE SOME SHELTER STUDENTS ENROLL IN NON-ZONED SCHOOOLS, THIS WOULD NOT BE AN INVOLUNTARY ASSIGNMENT;

		*DISPLAY REGRESSION TYPE IN LOG FILE;
    		di " " ;
    		di "OLS ";
    		di " ";

		*CONDUCT REGRESSION;
		areg `subject' katrina_frac_campus l`subject'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* 
			if female == `gender' & `subject'_quartile != ., cluster(campus) absorb(campus);
		outreg2 katrina_frac_campus using outreg_gender_ethnicity, excel nocons bdec(2);


  *CLOSE DEPVAR LOOP;
  };

  *LOOP OVER DEPENDENT VARIABLES;
  foreach subject of varlist perc_attn infrac {;
    
	*INCREASE COUNTER FOR DEPENDENT VARIABLE;
	local depvarid = `depvarid' + 1;


	*OLS - LIMIT TO ZONED SCHOOLS B/C LEASEABLE SPACE ONLY APPLY TO ZONED SCHOOLS;
	*ALSO WHILE SOME SHELTER STUDENTS ENROLL IN NON-ZONED SCHOOOLS, THIS WOULD NOT BE AN INVOLUNTARY ASSIGNMENT;

		*DISPLAY REGRESSION TYPE IN LOG FILE;
    		di " " ;
    		di "OLS ";
    		di " ";

		*CONDUCT REGRESSION;
		areg `subject' katrina_frac_campus l`subject'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* if female == `gender', cluster(campus) absorb(campus);
		outreg2 katrina_frac_campus using outreg_gender_ethnicity, excel nocons bdec(2);


  *CLOSE DEPVAR LOOP;
  };

*CLOSE GENDER LOOP;
};





* ==== APP TABLE 3: by-race panels (3=Black, 4=Hisp, 5=White) ====
* Each areg + outreg2 below writes one App Table 3 column for the race x outcome.
*LOOP OVER ETHNICITY/RACE;
*3 - BLACK, 4 - HISP, 5 - WHITE;
forvalues race = 3/5 {;

  *LOOP OVER DEPENDENT VARIABLES;
  foreach subject of varlist taks_sd_min_math taks_sd_min_read {;

	*INCREASE COUNTER FOR DEPENDENT VARIABLE;
	local depvarid = `depvarid' + 1;


	*OLS - LIMIT TO ZONED SCHOOLS B/C LEASEABLE SPACE ONLY APPLY TO ZONED SCHOOLS;
	*ALSO WHILE SOME SHELTER STUDENTS ENROLL IN NON-ZONED SCHOOOLS, THIS WOULD NOT BE AN INVOLUNTARY ASSIGNMENT;

		*DISPLAY REGRESSION TYPE IN LOG FILE;
    		di " " ;
    		di "OLS ";
    		di " ";

		*CONDUCT REGRESSION;
		areg `subject' katrina_frac_campus l`subject'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I*
			if ethnicity == `race' & `subject'_quartile != ., cluster(campus) absorb(campus);
		outreg2 katrina_frac_campus using outreg_gender_ethnicity, excel nocons bdec(2);

  *CLOSE DEPVAR LOOP;
  };

  *LOOP OVER DEPENDENT VARIABLES;
  foreach subject of varlist perc_attn infrac {;
    
	*INCREASE COUNTER FOR DEPENDENT VARIABLE;
	local depvarid = `depvarid' + 1;


	*OLS - LIMIT TO ZONED SCHOOLS B/C LEASEABLE SPACE ONLY APPLY TO ZONED SCHOOLS;
	*ALSO WHILE SOME SHELTER STUDENTS ENROLL IN NON-ZONED SCHOOOLS, THIS WOULD NOT BE AN INVOLUNTARY ASSIGNMENT;

		*DISPLAY REGRESSION TYPE IN LOG FILE;
    		di " " ;
    		di "OLS ";
    		di " ";

		*CONDUCT REGRESSION;
		areg `subject' katrina_frac_campus l`subject'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* if ethnicity == `race', cluster(campus) absorb(campus);
		outreg2 katrina_frac_campus using outreg_gender_ethnicity, excel nocons bdec(2);

  *CLOSE DEPVAR LOOP;
  };

*CLOSE RACE LOOP;
};

*CLOSE GRADELEVEL LOOP;
};