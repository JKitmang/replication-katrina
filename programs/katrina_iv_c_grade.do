*===============================================================================
* FILE:     katrina_iv_c_grade.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Analysis (Houston IV / 2SLS) — grade-level variant
* PRODUCES: Grade-level companion to katrina_iv_c.do (feeds the Houston grade-level
*           achievement spec battery, App Tables 4 & 5 / behavior App Table 41).
*
* PURPOSE:  Same OLS-vs-2SLS exercise as katrina_iv_c.do, but the endogenous
*           regressor is the GRADE-level evacuee share (katrina_frac_grade) rather
*           than the campus-level share. For each outcome it runs OLS, the first
*           stage on the Sept-13-2005 instrument, and 2SLS (ivreg2 with endogeneity
*           test). Results are streamed via postfile (no final save/export block here).
*
* INPUTS:   /work/i/imberman/imberman/katrina_data.dta   (HISD student panel)
* OUTPUTS:  /work/i/imberman/imberman/postfiles/ivregs.dta   (collected results)
*
* KEY STEPS:
*   - Open a postfile to collect regression results.
*   - Loop over grade level (elem, midhigh) and over 4 dependent variables.
*   - OLS of outcome on katrina_frac_grade with demographics + grade*year + campus FE.
*   - First stage: katrina_frac_grade on the Sept-13-2005 instrument; F-test.
*   - 2SLS (ivreg2) instrumenting katrina_frac_grade with the Sept-13 share.
*
* HARDCODED YEARS / PATHS TO UPDATE FOR A NEW-YEARS REPLICATION:
*   - Absolute paths /work/i/imberman/imberman/...  (input data, postfile output).
*   - Sept-13-2005 INSTRUMENT: katrina_frac_noRGB_9_13_05 = evacuee share measured
*     on 13-Sep-2005 EXCLUDING stadium/convention-center shelter ("noRGB") residents;
*     instrument for the later October grade evacuee share. Date baked into the name.
*
* NOTE: Documentation comments only — no executable code was modified.
*===============================================================================
*RUNS FIRST-STAGE & REDUCED FORM REGRESSIONS USING VARIOUS INSTRUMENT CANDIDATES


clear
set mem 3g
set matsize 2000
set more off

*REGRESSIONS

*USE DELIMITER TO ALLOW COMMANDS TO SPREAD LINES
# delimit ;


*OPEN UP FILE THAT WILL COLLECT REGRESSION RESULTS INTO A DATASET;
  postfile ivregs int(gradelevel reg depvarid indepvarid) 
	str40 (grade regdesc depvar indepvar instrument statname) 
	float(stat tstat obs) 
	using /work/i/imberman/imberman/postfiles/ivregs.dta, replace;


*COUNTERS ALLOW ME TO GENERATE UNIQUE IDENTIFIERS FOR EACH REGRESSION THAT CAN LATER BE SORTED IN A WAY THAT IS EASILY TRANSFERABLE TO EXCEL DATA TABLES;
*COUNTER FOR GRADE LEVEL;
local gradenum 0;

* ---- Loop over grade level (elem, midhigh); reload data each iteration ----
*LOOP OVER GRADE LEVEL;
foreach grade in "elem" "midhigh"{;

  *INCREASE COUNTER FOR GRADELEVEL (1 = ELEM, 2 = MIDHIGH);
  local gradenum = `gradenum' + 1;

  *OPEN TEMPORARY DATAFILE SAVED EARLIER IN PROGRAM;
  *PATH: repoint to your local globals.;
  use /work/i/imberman/imberman/katrina_data.dta, clear;

  *OPTION TO TAKE RANDOM SAMPLE FOR PROGRAM TESTING;
  *set seed 300083;
  *gsample 5, percent wor cluster(id);

  *KEEP ONLY GRADE LEVEL BEING ANALYSED IN SAMPLE;
  keep if `grade' == 1;

  *GENERATE GRADE X YEAR INTERACTIONS AND SCHOOL DUMMIES;
  xi i.grade*i.year i.campus;

  *DISPLAY GRADE LEVEL IN LOG FILE;
  di " ";
  di "`grade'";
  di " ";

  *COUNTER FOR DEPENDENT VARIABLE;
  local depvarid 0;

  *LOOP OVER DEPENDENT VARIABLES;
  foreach subject of varlist taks_sd_min_math taks_sd_min_read perc_attn infrac {;
    
	*INCREASE COUNTER FOR DEPENDENT VARIABLE;
	local depvarid = `depvarid' + 1;

	* ---- OLS: outcome on October grade-level evacuee share ----
	*OLS
		*DISPLAY REGRESSION TYPE IN LOG FILE;
    		di " " ;
    		di "OLS - ZONED";
    		di " ";

		*CONDUCT REGRESSION;
		reg `subject' katrina_frac_grade female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I*, cluster(campus);
		
    		*REGRESSION TYPE COUNTER;
	    	local reg 1;
 
	* ---- 2SLS using the Sept-13-2005 instrument (first stage + IV-SS) ----
	* SEPT-13-2005 IV: katrina_frac_noRGB_9_13_05 = evacuee share on 13-Sep-2005,
	* EXCLUDING stadium/convention-center shelter residents ("noRGB"). Instruments
	* the endogenous later (October) grade evacuee share katrina_frac_grade.;
	*2SLS - COMBINED INSTRUMETNS - USE ALL 3 INSTRUMENTS TOGETHER;

		local indepvarid 0;
		local instrument "katrina_frac_noRGB_9_13_05";
		local reg = `reg' + 1;

		di " ";
        	di "`instrument'";
        	di " ";

		* ---- First stage: grade evacuee share on Sept-13-2005 instrument ----
		*FIRST STAGE;

			di " " ;
      			di "first stage";
      			di " ";
      			reg katrina_frac_grade `instrument' female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* if `subject' !=., cluster(campus);

			*F-TEST OF JOINT SIGNIFICANCE OF EXCLUDED INSTRUMENTS;
			test `instrument';

		* ---- Second stage: 2SLS via ivreg2 with endogeneity (Hausman) test ----
		*SECOND STAGE - USE IVREG2 TO GET TEST OF ENDOGENEITY OF THE OLS ESTIMATES;

			di " ";
	      		di "2SLS";
      			di " ";

			local reg = `reg' + 1;

      			ivreg2 `subject' (katrina_frac_grade = `instrument') female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I*, 
				cluster(campus) noid endog(katrina_frac_grade) partial(_I*) small;



  *CLOSE DEPVAR LOOP;
  };

*CLOSE GRADELEVEL LOOP;
};
