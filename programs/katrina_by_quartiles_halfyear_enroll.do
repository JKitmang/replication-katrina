*===============================================================================
* FILE:     katrina_by_quartiles_halfyear_enroll.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Robustness/variant (Houston: evacuee effect vs. timing of arrival)
* PRODUCES: Appendix Table 8.
*
* PURPOSE:  Companion to katrina_by_quartiles_avgweeklyenroll_b.do. Instead of the
*           SD of weekly enrollment, it separates evacuees who entered in the FIRST
*           semester from those who entered in the SECOND semester (each as a share
*           of enrollment) alongside the average weekly evacuee share. This tests
*           whether mid-year arrivals (more disruptive timing) drive the estimated
*           peer effect.
*
* INPUTS:   /work/i/imberman/imberman/hisd_data.dta   (enrollment w/ entry/leave dates)
*           /work/i/imberman/imberman/katrina_data.dta (HISD analysis panel)
*           /work/i/imberman/imberman/pre_katrina_quartiles.dta (quartiles)
* OUTPUTS:  /work/i/imberman/imberman/weekly_enrollment.dta (campus-grade-year)
*           semenr.xls/.txt via outreg2 (App Table 8)
*
* KEY STEPS:
*   - Parse entry/leave dates; drop bad/early records; build weekly enrollment flags.
*   - Flag 1st- vs 2nd-semester evacuee entry; interact with evacuee status.
*   - Collapse to campus-grade-year; form avg weekly share + semester-entry shares.
*   - Loop grade level; rebuild test lags; merge churn + baseline quartiles.
*   - reg outcome on avg share + sem1/sem2 entry shares; pooled & by quartile via outreg2.
*
* HARDCODED YEARS / PATHS TO UPDATE FOR A NEW-YEARS REPLICATION:
*   - keep if year >= 2003   (first enrollment year retained)
*   - ACADEMIC-YEAR START DATES for the weekly calendar:
*     081803 (2003), 081604 (2004), 081505/081504 (2005), 081406/080706 (2006).
*   - SEMESTER-SPLIT DATES per year: Aug-1 / Jan-1 anchors (080103,010104, ...,010107).
*   - year(entry)>2004/2005/2006/2007 and month()==7/8 record-cleaning rules per year.
*   - replace katrina = 0 if year < 2005   (no evacuees before treatment year).
*   - lag construction uses l`lag'.year <= 2004 (pre/at-treatment lag cap).
*   - Absolute path cd /work/i/imberman/imberman/ and all use/save/merge paths.
*
* NOTE: Documentation comments only — no executable code was modified.
*===============================================================================

*UNRESTRICTED VALUE-ADDED REGRESSIONS

***IDENTIFY AN EVACUEE EFFECT AND SEPARATE DISRUPTION EFFECT

***THIS MODEL USES THE AVERAGE WEEKLY EVACUEE SHARE BUT INSTEAD OF ALSO CONTROLLING FOR STANDARD DEVIATION IN EVACUEE SHARE
***WE CONTROL FOR 1ST HALF EVAC ENTRIES AS A SHARE OF ENROLLMENT & 2ND HALF EVAC ENTRIES AS A SHARE OF ENROLLMENT


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

   * ---- Flag 1st- vs 2nd-semester entry (DATE HARDCODE: Aug-1 / Jan-1 anchors) ----
   *IDENTIFY WHETHER EVACUEE ENTERS IN 1ST OR 2ND HALF OF YEAR;
   gen sem1_entry = 0
   replace sem1_entry = 1  if  entry >=  date("080103","MD20Y") & entry < date("010104","MD20Y") & year == 2003   // DATE HARDCODE: fall 2003 semester
   replace sem1_entry = 1  if  entry >=  date("080104","MD20Y") & entry < date("010105","MD20Y") & year == 2004   // DATE HARDCODE: fall 2004 semester
   replace sem1_entry = 1  if  entry >=  date("080105","MD20Y") & entry < date("010106","MD20Y") & year == 2005   // DATE HARDCODE: fall 2005 semester
   replace sem1_entry = 1  if  entry >=  date("080106","MD20Y") & entry < date("010107","MD20Y") & year == 2006   // DATE HARDCODE: fall 2006 semester


   gen sem2_entry = 0
   replace sem2_entry = 1  if  entry >=  date("010104","MD20Y") & entry < date("080104","MD20Y") & year == 2003   // DATE HARDCODE: spring 2004 semester
   replace sem2_entry = 1  if  entry >=  date("010105","MD20Y") & entry < date("080105","MD20Y") & year == 2004   // DATE HARDCODE: spring 2005 semester
   replace sem2_entry = 1  if  entry >=  date("010106","MD20Y") & entry < date("080106","MD20Y") & year == 2005   // DATE HARDCODE: spring 2006 semester
   replace sem2_entry = 1  if  entry >=  date("010107","MD20Y") & entry < date("080107","MD20Y") & year == 2006   // DATE HARDCODE: spring 2007 semester

   


* ---- Collapse to campus-grade-year; form share + semester-entry measures ----
*COLLAPSE TO CAMPUS YEAR GRADE DATASET
  replace katrina = 0 if year < 2005   // YEAR HARDCODE: no evacuees before 2005-06 treatment year

   *IDENTIFY EVACUEES WITH GIVEN ENTRY TIMES
   gen sem1_entry_kat = sem1_entry*katrina
   gen sem2_entry_kat = sem2_entry*katrina


  collapse (sum) week_* katrina_week_* (mean) sem*entry*kat, by(campus year grade)
 
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


  * ---- Merge churn/semester-entry measures + baseline quartiles ----
  *MERGE IN WEEKLY ENROLLMENT DATA
  sort campus grade year
  drop _merge
  *PATH: repoint to your local globals.
  merge campus grade year using /work/i/imberman/imberman/weekly_enrollment.dta, keep(avg* sd* sem*) nokeep
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

	* ---- Test-score outcomes: avg share + sem1/sem2 entry shares (App Tbl 8) ----
	* Output streamed to semenr.xls via outreg2; ctitle marks each column.;
	capture drop semenr.txt;
	capture drop semenr.xls;
	capture drop semenr.xml;

  	reg `var' avg_katrina_weekly_enr sem1_entry_kat sem2_entry_kat  l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* if `var' != . & `var'_quartile != ., cluster(campus);
	outreg2 avg_katrina_weekly_enr sem1_entry_kat sem2_entry_kat using semenr, excel dec(2) ctitle("`var',`grade', All");

 
	 	*LOOP OVER QUARTILES;
	 	foreach quartile of numlist 1/4 {;
 
	  	di "" ;
	  	di "QUARTILE `quartile'";
	  	di "";

	 	reg `var' avg_katrina_weekly_enr  sem1_entry_kat sem2_entry_kat l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* 
			if `var' != . & `var'_quartile == `quartile', cluster(campus);
		outreg2 avg_katrina_weekly_enr  sem1_entry_kat sem2_entry_kat using semenr, excel dec(2) ctitle("`var',`grade', Quartile `quartile'");
		};


  };
 
  * ---- Behavior outcomes (attendance, infractions): avg + sem1/sem2 shares ----
  foreach var of varlist perc_attn infractions{;

	capture drop semenr.txt;
	capture drop semenr.xls;


        *OLS KATRINA & SD ENROLL;
  	reg `var' avg_katrina_weekly_enr  sem1_entry_kat sem2_entry_kat  l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* if `var' != ., cluster(campus);
	outreg2 avg_katrina_weekly_enr  sem1_entry_kat sem2_entry_kat using semenr, excel dec(2) ctitle("`var',`grade', All");

};
 

*CLOSE GRADELEVEL LOOP;
};


