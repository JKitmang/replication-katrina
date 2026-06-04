*===============================================================================
* FILE:     katrina_by_quartiles_avgweeklyenroll_b.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Robustness/variant (Houston: evacuee effect vs. enrollment-disruption)
* PRODUCES: Appendix Tables 7 & 42.
*
* PURPOSE:  Separates a pure evacuee peer effect from a generic enrollment-DISRUPTION
*           effect. Reconstructs weekly enrollment for each campus/grade from student
*           entry/leave dates, then builds (a) the average weekly evacuee share and
*           (b) the SD of relative weekly enrollment as a churn/disruption measure.
*           Runs OLS (evacuee share only; share + disruption SD), the first stage of
*           the disruption SD on the SD of the evacuee weekly count, and 2SLS that
*           instruments disruption with evacuee churn — pooled and by quartile.
*
* INPUTS:   /work/i/imberman/imberman/hisd_data.dta   (enrollment w/ entry/leave dates)
*           /work/i/imberman/imberman/katrina_data.dta (HISD analysis panel)
*           /work/i/imberman/imberman/pre_katrina_quartiles.dta (quartiles)
* OUTPUTS:  /work/i/imberman/imberman/weekly_enrollment.dta (campus-grade-year churn)
*           avgenr_<outcome>.xls/.txt via outreg2 (App Tables 7 & 42)
*
* KEY STEPS:
*   - Parse entry/leave dates; drop bad/early records; zero evacuees before 2005.
*   - For each academic-year week, flag enrolled students and evacuee-enrolled.
*   - Collapse to campus-grade-year; form avg weekly share, SD of relative enroll, churn.
*   - Loop grade level; rebuild test lags; merge churn + baseline quartiles.
*   - OLS / first stage / 2SLS per outcome, pooled and by quartile, via outreg2.
*
* HARDCODED YEARS / PATHS TO UPDATE FOR A NEW-YEARS REPLICATION:
*   - keep if year >= 2003   (first enrollment year retained)
*   - Many explicit ACADEMIC-YEAR START DATES used to build the weekly calendar:
*     081803 (2003), 081604 (2004), 081505/081504 (2005), 081406/080706 (2006).
*     These are the per-year first-day-of-school anchors; repoint for new years.
*   - year(entry)>2004/2005/2006/2007 and month()==7/8 record-cleaning rules per year.
*   - replace katrina = 0 if year < 2005   (no evacuees before treatment year).
*   - lag construction uses l`lag'.year <= 2004 (pre/at-treatment lag cap).
*   - Absolute path cd /work/i/imberman/imberman/ and all use/save/merge paths.
*
* NOTE: Documentation comments only — no executable code was modified.
*===============================================================================

*UNRESTRICTED VALUE-ADDED REGRESSIONS

***IDENTIFY AN EVACUEE EFFECT AND SEPARATE DISRUPTION EFFECT

***USE VARIANCE IN WEEKLY ENROLLMENT RELATIVE TO SNAPSHOT ENROLLMENT AS MEASURE OF DISRUPTION
***NEED TO USE SCHOOL LEVEL ENROLLMENT AS GRADE IS UNOBSERVED FOR STUDENTS ENTERING AFTER SNAPSHOT DATE***


clear
set mem 3g
set matsize 2000
set more off

set seed 105253

***OPTIONS****



  *PATH: repoint to your local globals.
  cd /work/i/imberman/imberman/

* ---- Build disruption dataset: parse entry/leave dates, clean records ----
*GENERATE DATASET WITH DISRUPTION DATA

    *PATH: repoint to your local globals.
    use /work/i/imberman/imberman/hisd_data.dta, clear
    keep if year >= 2003   // YEAR HARDCODE: 2003 = first enrollment year retained
    drop if enter_date == "000000"
    gen entry = date(enter_date, "MD20Y")
    format entry %td
    drop if entry == .
    gen leave = date(leave_date, "MD20Y")
    format leave %td
   
   
    * ---- Record cleaning: drop implausible entry dates (per-year rules) ----
    *DROP OBS THAT APPEAR TO HAVE INCORRECT DATA
    drop if year == 2003 & year(entry) > 2004   // YEAR HARDCODE: 2003-04 entries must be in 2003/2004
    drop if year == 2004 & year(entry) > 2005   // YEAR HARDCODE: 2004-05 entries must be in 2004/2005
    drop if year == 2005 & (year(entry) > 2006 | (year(entry) == 2006 & month(entry) == 7))   // YEAR HARDCODE: 2005-06 window
    drop if year == 2006 & (year(entry) > 2007 | (year(entry) == 2007 & month(entry) == 8))   // YEAR HARDCODE: 2006-07 window

    *DROP OBS WHERE ENTRY DATE IS PRIOR TO START OF SCHOOL YEAR
    *DATE HARDCODE: per-year first day of school (MMDDYY); repoint for new years.
    drop if entry < date("081803", "MD20Y") & year == 2003   // DATE HARDCODE: 18-Aug-2003 start
    drop if entry < date("081604", "MD20Y") & year == 2004   // DATE HARDCODE: 16-Aug-2004 start
    drop if entry < date("081504", "MD20Y") & year == 2005   // DATE HARDCODE: 2005-06 start (note: literal is 081504)
    drop if entry < date("080706", "MD20Y") & year == 2006   // DATE HARDCODE: 07-Aug-2006 start

    ****NOTE THAT THERE SEEMS TO BE SOME ERROR WITH THE 2006 DATA AS A LOT OF ENTRY IS LISTED AS PRIOR YEAR
    ****MY DECISION WAS TO DROP THESE OBSERVATIONS, HOWEVER I NEED TO CHECK IN REGRESSIONS THAT DROP 2006 TO MAKE SURE THIS NOT A CONCERN
  

    * ---- Build weekly enrollment flags for natives + evacuees ----
    *GENERATE WEAKLY ENROLLMENT FIGURES FOR BOTH REGULAR & EVACUEES
    replace katrina = 0 if year < 2005   // YEAR HARDCODE: no evacuees before 2005-06 treatment year
    *DATE HARDCODE: weekly enrollment anchored to per-year school-start dates below.
    # delimit ;
    forvalues week = 33/50 {;
	local week_ay = `week' - 32;
	gen byte week_`week_ay' = 0;
        replace week_`week_ay' = 1 if entry < date("081803", "MD20Y") + 7*`week_ay' & year == 2003 & 
		(leave >= date("081803","MD20Y") + 7*`week_ay' | leave == .);
        replace week_`week_ay' = 1 if entry < date("081604", "MD20Y") + 7*`week_ay' & year == 2004 &
		(leave >= date("081604","MD20Y") + 7*`week_ay' | leave == .);
        replace week_`week_ay' = 1 if entry < date("081505", "MD20Y") + 7*`week_ay' & year == 2005 &
		(leave >= date("081505","MD20Y") + 7*`week_ay' | leave == .);
        replace week_`week_ay' = 1 if entry < date("081406", "MD20Y") + 7*`week_ay' & year == 2006 &
		(leave >= date("081406","MD20Y") + 7*`week_ay' | leave == .);
	gen katrina_week_`week_ay' = week_`week_ay'*katrina;
   };
    forvalues week = 1/21 {;
	local week_ay = `week' + 18;
	gen byte week_`week_ay' = 0;
        replace week_`week_ay' = 1 if entry < date("081803", "MD20Y") + 7*`week_ay' & year == 2003 & 
		(leave >= date("081803","MD20Y") + 7*`week_ay' | leave == .);
        replace week_`week_ay' = 1 if entry < date("081604", "MD20Y") + 7*`week_ay' & year == 2004 &
		(leave >= date("081604","MD20Y") + 7*`week_ay' | leave == .);
        replace week_`week_ay' = 1 if entry < date("081505", "MD20Y") + 7*`week_ay' & year == 2005 &
		(leave >= date("081505","MD20Y") + 7*`week_ay' | leave == .);
        replace week_`week_ay' = 1 if entry < date("081406", "MD20Y") + 7*`week_ay' & year == 2006 &
		(leave >= date("081406","MD20Y") + 7*`week_ay' | leave == .);
	gen katrina_week_`week_ay' = week_`week_ay'*katrina;
   };
# delimit cr
   


* ---- Collapse to campus-grade-year; form share + disruption measures ----
*COLLAPSE TO CAMPUS YEAR GRADE DATASET
  replace katrina = 0 if year < 2005   // YEAR HARDCODE: no evacuees before 2005-06 treatment year
  collapse (sum) week_* katrina_week_*, by(campus year grade)
 
  *REPLACE WEEKLY KATRINA COUNT W/ WEEKLY KATRINA SHARE
  egen avg_weekly_enr = rmean(week_*)
  forvalues week = 1/39 {
   replace katrina_week_`week' = katrina_week_`week'/week_`week'
   gen rel_weekly_enr_`week' = week_`week'/avg_weekly_enr
  }

  egen avg_katrina_weekly_enr = rmean(katrina_week_*)
  egen sd_weekly_enr = rsd(week_*)
  egen sd_rel_weekly_enr = rsd(rel_weekly_enr_*)
  egen sd_katrina_weekly_enr = rsd(katrina_week_*)
  sort campus grade year
  *PATH: repoint to your local globals.
  save /work/i/imberman/imberman/weekly_enrollment.dta, replace

*LOOP OVER GRADE LEVEL
foreach grade in "elem" "midhigh"{

  *INCREASE COUNTER FOR GRADELEVEL (1 = ELEM, 2 = MIDHIGH)
  local gradenum = `gradenum' + 1

  *OPEN KATRINA DATA
  use /work/i/imberman/imberman/katrina_data.dta, clear
  xtset id year

  * ---- Build pre-Katrina test-score lags (gap dummies x lagged score) ----
  *GENEARATE TEST SCORE LAGS FROM PRE-KATRINA YEARS
  foreach var of varlist taks_sd_min_math taks_sd_min_read perc_attn infractions {
  gen l`var' = .
  gen lagyears_`var' = .
  foreach lag of numlist 1/5 {
    replace lagyears_`var' = `lag' if l`var' == . & l`lag'.`var' != . & l`lag'.year <= 2004   // YEAR HARDCODE: only lags from years <=2004
    replace l`var' = l`lag'.`var' if l`var' == . & l`lag'.`var' != . & l`lag'.year <= 2004   // YEAR HARDCODE: lag source capped at 2004
  }
  tab lagyears_`var', gen(lagyears_`var'_)
  forvalues gap = 1/4 {
    gen l`var'_`gap' = lagyears_`var'_`gap'*l`var'
  }
  }


  * ---- Merge churn/disruption measures + baseline quartiles ----
  *MERGE IN WEEKLY ENROLLMENT DATA
  sort campus grade year
  drop _merge
  *PATH: repoint to your local globals.
  merge campus grade year using /work/i/imberman/imberman/weekly_enrollment.dta, keep(avg* sd*) nokeep
  xtset id year

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
  *PATH: repoint to your local globals.   BASELINE ACHIEVEMENT QUARTILES merged here.
  merge id year using /work/i/imberman/imberman/pre_katrina_quartiles.dta, _merge(_mergequartile) nokeep


  *GENERATE GRADE X YEAR INTERACTIONS AND SCHOOL DUMMIES
  xi i.grade*i.year i.campus

  *DISPLAY GRADE LEVEL IN LOG FILE
  di " "
  di "`grade'"
  di " "

  di ""
  di "POOLED LINEAR MODEL"
  di ""

  # delimit ;


  foreach var of varlist taks_sd_min_math taks_sd_min_read {;

	* ---- Test-score outcomes: OLS / OLS+disruption / first stage / 2SLS (App Tbl 7) ----
	* Output streamed to avgenr_<outcome>.xls via outreg2; ctitle marks each column.;
	capture drop avgenr_`var'.txt;
	capture drop avgenr_`var'.xls;
	capture drop avgenr_`var'.xml;

	*OLS KATRINA ONLY;
	reg `var' avg_katrina_weekly_enr  l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* if `var' != . & `var'_quartile != ., cluster(campus);
	outreg2 avg_katrina_weekly_enr using avgenr_`var', excel dec(2) ctitle("`var',OLS-Mean, ALL");

	 	*LOOP OVER QUARTILES;
	 	foreach quartile of numlist 1/4 {;
 
	  	di "" ;
	  	di "QUARTILE `quartile'";
	  	di "";

		reg `var' avg_katrina_weekly_enr  l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* 
			if `var' != . & `var'_quartile == `quartile', cluster(campus);
		outreg2 avg_katrina_weekly_enr using avgenr_`var', excel dec(2) ctitle("`var',OLS-Mean, Quartile `quartile'");
		};



        *OLS KATRINA & SD ENROLL;
  	reg `var' avg_katrina_weekly_enr sd_rel_weekly_enr  l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* if `var' != . & `var'_quartile != ., cluster(campus);
	outreg2 avg_katrina_weekly_enr sd_rel_weekly_enr using avgenr_`var', excel dec(2) ctitle("`var',OLS-Mean&SD, All");

 
	 	*LOOP OVER QUARTILES;
	 	foreach quartile of numlist 1/4 {;
 
	  	di "" ;
	  	di "QUARTILE `quartile'";
	  	di "";

	 	reg `var' avg_katrina_weekly_enr  sd_rel_weekly_enr l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* 
			if `var' != . & `var'_quartile == `quartile', cluster(campus);
		outreg2 avg_katrina_weekly_enr sd_rel_weekly_enr using avgenr_`var', excel dec(2) ctitle("`var',OLS-Mean&SD, Quartile `quartile'");
		};


	* First stage: regress disruption SD on evacuee weekly-count SD (instrument).;
	*FIRST STAGE;
	reg sd_rel_weekly_enr avg_katrina_weekly_enr sd_katrina_weekly_enr l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* if `var' != . & `var'_quartile != ., cluster(campus);
	outreg2  sd_katrina_weekly_enr avg_katrina_weekly_enr using avgenr_`var', excel dec(2) ctitle("`var',FS-Mean&SD, All");

	
	 	*LOOP OVER QUARTILES;
	 	foreach quartile of numlist 1/4 {;
 
	  	di "" ;
	  	di "QUARTILE `quartile'";
	  	di "";
		reg sd_rel_weekly_enr sd_katrina_weekly_enr  avg_katrina_weekly_enr l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* 
			if `var' != . & `var'_quartile == `quartile', cluster(campus);
		outreg2 sd_katrina_weekly_enr avg_katrina_weekly_enr using avgenr_`var', excel dec(2) ctitle("`var',FS-Mean&SD, Quartile `quartile'");	
		};


	* 2SLS: instrument disruption SD (sd_rel_weekly_enr) with evacuee churn SD.;
	*2SLS;
	ivreg `var' avg_katrina_weekly_enr ( sd_rel_weekly_enr = sd_katrina_weekly_enr)  l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* if `var'_quartile != ., cluster(campus);
	outreg2 avg_katrina_weekly_enr sd_rel_weekly_enr using avgenr_`var', excel dec(2) ctitle("`var',SS-Mean&SD, All");

	 	*LOOP OVER QUARTILES;
	 	foreach quartile of numlist 1/4 {;
 
	  	di "" ;
	  	di "QUARTILE `quartile'";
	  	di "";
		ivreg `var' avg_katrina_weekly_enr ( sd_rel_weekly_enr = sd_katrina_weekly_enr)  l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I*  
			if `var' != . & `var'_quartile == `quartile', cluster(campus);
		outreg2 avg_katrina_weekly_enr sd_rel_weekly_enr using avgenr_`var', excel dec(2) ctitle("`var',SS-Mean&SD, Quartile `quartile'");
		};


  };
 
  * ---- Behavior outcomes (attendance, infractions): OLS / FS / 2SLS (App Tbl 42) ----
  foreach var of varlist perc_attn infractions{;

	capture drop avgenr_`var'.txt;
	capture drop avgenr_`var'.xls;

	*OLS KATRINA ONLY;
	reg `var' avg_katrina_weekly_enr  l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* if `var' != ., cluster(campus);
	outreg2 avg_katrina_weekly_enr using avgenr_`var', excel dec(2) ctitle("`var',OLS-Mean, ALL");


        *OLS KATRINA & SD ENROLL;
  	reg `var' avg_katrina_weekly_enr sd_rel_weekly_enr  l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* if `var' != ., cluster(campus);
	outreg2 avg_katrina_weekly_enr sd_rel_weekly_enr using avgenr_`var', excel dec(2) ctitle("`var',OLS-Mean&SD, All");

	*FIRST STAGE;
	reg sd_rel_weekly_enr avg_katrina_weekly_enr sd_katrina_weekly_enr l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* if `var' != ., cluster(campus);
	outreg2  sd_katrina_weekly_enr avg_katrina_weekly_enr using avgenr_`var', excel dec(2) ctitle("`var',FS-Mean&SD, All");


	*2SLS;
	ivreg `var' avg_katrina_weekly_enr ( sd_rel_weekly_enr = sd_katrina_weekly_enr)  l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I*, cluster(campus);
	outreg2 avg_katrina_weekly_enr sd_rel_weekly_enr using avgenr_`var', excel dec(2) ctitle("`var',SS-Mean&SD, Quartile `quartile'");
};
 

*CLOSE GRADELEVEL LOOP;
};


