*===============================================================================
* FILE:     katrina_iv_c.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Analysis (Houston IV / 2SLS)
* PRODUCES: Appendix Tables 4 & 5 (first entry of the Houston grade-level
*           achievement spec battery) and App Table 41 (behavior battery).
*           Houston OLS vs. 2SLS comparison for the campus-level evacuee share.
*
* PURPOSE:  Estimates the effect of the campus-level evacuee ("Katrina") share on
*           incumbents' TAKS math/read scores, attendance, and infractions in HISD.
*           For each outcome it runs (1) OLS on the October campus evacuee share,
*           (2) the first stage of that share on the Sept-13-2005 instrument, and
*           (3) 2SLS via ivreg2 (with an endogeneity/Hausman test). Results are
*           streamed via postfile into a results dataset for export to Excel.
*
* INPUTS:   /work/i/imberman/imberman/katrina_data.dta   (HISD student panel)
* OUTPUTS:  /work/i/imberman/imberman/postfiles/ivregs.dta   (collected results)
*           /work/i/imberman/imberman/postfiles/ivregs.dat   (tab-delimited export)
*
* KEY STEPS:
*   - Open a postfile to collect coefficients/SEs/N for every regression.
*   - Loop over grade level (elem, midhigh) and over 4 dependent variables.
*   - OLS of outcome on katrina_frac_campus with demographics + grade*year + campus FE.
*   - First stage: katrina_frac_campus on the Sept-13-2005 instrument; F-test.
*   - 2SLS (ivreg2) instrumenting katrina_frac_campus with the Sept-13 share.
*   - Close postfile, sort, and outsheet to a tab-delimited .dat file.
*
* HARDCODED YEARS / PATHS TO UPDATE FOR A NEW-YEARS REPLICATION:
*   - Absolute paths /work/i/imberman/imberman/...  (input data, postfiles output).
*   - Sept-13-2005 INSTRUMENT: katrina_frac_noRGB_9_13_05 = evacuee share measured
*     on 13-Sep-2005 EXCLUDING stadium/convention-center shelter ("noRGB") residents;
*     this is the IV for the later October campus share. Year is baked into the
*     variable name and the dataset it comes from.
*   - No explicit `keep if year==` filters here, but the treatment year (2005-06)
*     and the instrument date are implicit in the input data and variable names.
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


* ---- Open postfile to collect regression results into a dataset ----
* PATH: repoint to your local globals.
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

	* ---- OLS: outcome on October campus evacuee share (App Tbl 4/5 OLS row) ----
	*OLS
		*DISPLAY REGRESSION TYPE IN LOG FILE;
    		di " " ;
    		di "OLS - ZONED";
    		di " ";

		*CONDUCT REGRESSION;
		reg `subject' katrina_frac_campus female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I*, cluster(campus);
		
    		*REGRESSION TYPE COUNTER;
	    	local reg 1;

    		*ADD REGRESSION RESULTS TO DATAFILE;
		local indepvar "katrina_frac_campus";
		post ivregs (`gradenum') (`reg') (`depvarid') (1) ("`grade'") ("OLS ") ("`subject'") 
			("`indepvar'") ("") ("coef") (_b[`indepvar']) (_b[`indepvar']/_se[`indepvar']) (e(N));
    		post ivregs (`gradenum') (`reg') (`depvarid') (1) ("`grade'") ("OLS ") ("`subject'") 
			("`indepvar'") ("") ("se") (_se[`indepvar']) (_b[`indepvar']/_se[`indepvar']) (e(N));
 
	* ---- 2SLS using the Sept-13-2005 instrument (first stage + IV-SS) ----
	* SEPT-13-2005 IV: katrina_frac_noRGB_9_13_05 = evacuee share on 13-Sep-2005,
	* EXCLUDING stadium/convention-center shelter residents ("noRGB"). Instruments
	* the endogenous later (October) campus evacuee share katrina_frac_campus.;
	*2SLS - COMBINED INSTRUMETNS - USE ALL 3 INSTRUMENTS TOGETHER;

		local indepvarid 0;
		local instrument "katrina_frac_noRGB_9_13_05";
		local reg = `reg' + 1;

		di " ";
        	di "`instrument'";
        	di " ";

		*FIRST STAGE;
      			
			di " " ;
      			di "first stage";
      			di " ";
      			reg katrina_frac_campus `instrument' female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* if `subject' !=., cluster(campus);

			*F-TEST OF JOINT SIGNIFICANCE OF EXCLUDED INSTRUMENTS;
			test `instrument';
      
			*LOAD REGRESSION RESULTS INTO DATASET;
      			foreach var in "katrina_frac_noRGB_9_13_05" {;
        			local indepvar "`var'";
        			local indepvarid = `indepvarid' + 1;
       				post ivregs (`gradenum') (`reg') (`depvarid') (`indepvarid') ("`grade'") ("IV-FS all") ("`subject'") ("`indepvar'") ("`var'")
					("coef") (_b[`indepvar']) (_b[`indepvar']/_se[`indepvar']) (e(N));
        			post ivregs (`gradenum') (`reg') (`depvarid') (`indepvarid') ("`grade'") ("IV-FS all") ("`subject'") ("`indepvar'") ("`var'")
					("se") (_se[`indepvar']) (_b[`indepvar']/_se[`indepvar']) (e(N));
      			};


		* ---- Second stage: 2SLS via ivreg2 with endogeneity (Hausman) test ----
		*SECOND STAGE - USE IVREG2 TO GET TEST OF ENDOGENEITY OF THE OLS ESTIMATES;

			di " ";
	      		di "2SLS";
      			di " ";

			local reg = `reg' + 1;

      			ivreg2 `subject' (katrina_frac_campus = `instrument') female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I*, 
				cluster(campus) noid endog(katrina_frac_campus) partial(_I*) small;
      			local indepvar "katrina_frac_campus";
      			post ivregs (`gradenum') (`reg') (`depvarid') (1) ("`grade'") ("IV-SS") ("`subject'") ("`indepvar'") ("all")
				("coef") (_b[`indepvar']) (_b[`indepvar']/_se[`indepvar']) (e(N));
      			post ivregs (`gradenum') (`reg') (`depvarid') (1) ("`grade'") ("IV-SS") ("`subject'") ("`indepvar'") ("all") 
				("se") (_se[`indepvar']) (_b[`indepvar']/_se[`indepvar']) (e(N));

  *CLOSE DEPVAR LOOP;
  };

*CLOSE GRADELEVEL LOOP;
};

* ---- Close postfile and export results to tab-delimited .dat for tables ----
* PATH: repoint to your local globals.
*SAVE RESULTS DATASET;
postclose ivregs;

*OPEN RESULTS DATASET, SORT, AND RESAVE AS A TAB-DELIMITED FILE;
use /work/i/imberman/imberman/postfiles/ivregs.dta, clear;
sort gradelevel reg indepvarid depvarid instrument statname;
outsheet using /work/i/imberman/imberman/postfiles/ivregs.dat, replace;
