*===============================================================================
* FILE:     attendence.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Data cleaning
* PRODUCES: Intermediate dataset attend_zip_katrina.dta (one of the inputs to
*           the master Houston merge in merge_c.do)
*
* PURPOSE:  Loads the raw HISD Average-Daily-Attendance (ADA) tables for every
*           school year via ODBC, harmonizes inconsistent variable names across
*           year vintages, appends them into a single panel, cleans IDs / zip /
*           enter-leave dates, and builds the student-level Katrina/Rita evacuee
*           indicator (carried forward from 2005 to 2006). Output is a clean
*           id-year attendance file with zip codes and the evacuee flag.
*
* INPUTS:   ODBC source "ada_discip_b", tables "<year>-ADA-ZIP" (1993-94..2006-07)
* OUTPUTS:  attend_zip_katrina.dta
*
* KEY STEPS:
*   - Pull each year's ADA-ZIP table from ODBC; keep/rename to a common schema
*   - Append all years into one panel; destring keys
*   - Backfill missing attendance rate from days present / days enrolled
*   - Null out odd pre-1995 enter/leave dates, status, and zip codes
*   - De-duplicate id-year records (entry-date / zip conflicts)
*   - Build katrina evacuee indicator; carry 2005 value forward to 2006
*   - Compute days each evacuee stayed in HISD in 2005
*
* HARDCODED YEARS / PATHS TO UPDATE FOR A NEW-YEARS REPLICATION:
*   - cd "C:\D\Research\Charter\Houston\HISDdata\DataFiles\2007_additions"  (PATH)
*   - save "C:\D\...\2007_additions\attend_zip_katrina.dta"                 (PATH)
*   - Hardcoded year-string lists in every foreach loop (1993-94 .. 2006-07)
*   - if "`year'" == "2003-04"            (YEAR HARDCODE)
*   - append loop ends at "2005-06"       (YEAR HARDCODE: drops 2006-07 append)
*   - replace ... if year < 1995          (YEAR HARDCODE: pre-1995 quirks)
*   - zip fix: if year == 2006            (YEAR HARDCODE)
*   - katrina = l.katrina if year == 2006 (YEAR HARDCODE: carry 2005 -> 2006)
*   - replace katrina = . if year < 2005  (YEAR HARDCODE: pre-treatment = no evacuees)
*   - katrina_timeinhisd ... if year == 2005 (YEAR HARDCODE: evacuee dwell time)
*
* NOTE: Documentation comments only — no executable code was modified.
*===============================================================================
clear
set mem 700m
set more off
cd "C:\D\Research\Charter\Houston\HISDdata\DataFiles\2007_additions"   // PATH: repoint to your local globals

* ---- Load raw ADA-ZIP tables (1993-94 & 1994-95 vintage schema) via ODBC ----
*MAKE INTO STATA DATASETS
foreach year in "1993-94" "1994-95" {
 clear
  odbc load, dialog(complete) dsn("ada_discip_b") table("`year'-ADA-ZIP") lowercase 
  keep year id zip_code sch* status per_attd gender eth f_lun dob t_*
  replace year = "`year'"
  rename per_attd perc_attn
  rename eth ethnicity
  rename f_lun lunch
  destring perc_attn t_*, replace
  compress
  sort id
  save ada-`year', replace
}


* ---- Load mid-period ADA-ZIP tables (1995-96..2004-05; adds enter/leave dates) ----
foreach year in "1995-96" "1996-97" "1997-98" "1998-99" "1999-00" "2000-01" "2001-02" "2002-03" "2003-04" "2004-05" {
  clear
  odbc load, dialog(complete) dsn("ada_discip_b") table("`year'-ADA-ZIP") lowercase
  if "`year'" == "2003-04" gen year = "2003-04"    // YEAR HARDCODE: 2003-04 file lacks year var
  keep year id zip_code enter_date leave_date sch* status perc_attn gender ethnicity lunch dob t_*
  replace year = "`year'"
  rename perc_attnd perc_attn
  destring perc_attn t_*, replace
  compress
  sort id
  save ada-`year', replace
}


* ---- Load post-Katrina ADA-ZIP tables (2005-06 & 2006-07; adds katrina var) ----
foreach year in  "2005-06"  "2006-07" {
  clear
  odbc load, dialog(complete) dsn("ada_discip_b") table("`year'-ADA-ZIP") lowercase
  keep year id zip_code enter_date leave_date sch* status perc_attn gender ethnicity lunch dob katrina t_d*   // katrina var only exists 2005-06 onward
  rename perc_attnd perc_attn
  replace year = "`year'"
  destring perc_attn t_*,  replace
  compress
  sort id
  save ada-`year', replace
}

* ---- Append all single-year files into one panel ----
* YEAR HARDCODE: list stops at "2005-06" (2006-07 file is NOT appended here)
foreach year in "1993-94" "1994-95" "1995-96" "1996-97" "1997-98" "1998-99" "1999-00" "2000-01" "2001-02" "2002-03" "2003-04" "2004-05" "2005-06" {
  append using ada-`year'
}

* ---- Clean up variables ----
*CLEAN UP VARIABLES
replace year = substr(year,1,4)   // keep first 4 chars -> calendar year of fall term
destring year id zip_code sch* gender ethnicity lunch , replace

  *SOME PERC_ATTN IS MISSING... REPLACE WITH DAYS PRESENT DIVIDED BY DAYS ENROLLED
  count if perc_attn != . & t_days_t == .
  count if perc_attn == . & t_days_t != .
  replace perc_attn = 100*t_days_p/t_days_t
  sum perc_attn

  *ENTER DATES & LEAVE DATES ARE ODD FOR PRE 1995, SO SET THOSE TO MISSING
   replace enter_date = "" if year < 1995   // YEAR HARDCODE: pre-1995 dates unreliable
   replace leave_date = "" if year < 1995   // YEAR HARDCODE: pre-1995 dates unreliable

  *STATUS & ZIP CODE VARIABLES GENERATE DUPLICATES IN 1993 & 1994, SO DROP FOR THOSE YEARS
   replace status = "" if year < 1995       // YEAR HARDCODE: drop status for 1993/1994
   replace zip_code = . if year < 1995      // YEAR HARDCODE: drop zip for 1993/1994

* ---- De-duplicate id-year records (entry-date and zip conflicts) ----
  *THERE ARE 4 OBS IN 2006 WITH SAME ID BUT DIFFERENT ENTRY DATES... WILL SET THESE ENTRY DATES TO MISSING
  duplicates drop
  duplicates tag id year, gen(dup)
  replace enter_date = "" if dup == 1
  duplicates drop

  *IN ADDITION FOR SOME OF THESE OBS THE ZIP CODE IS MISSING IN ONE AND NOT THE OTHER... DROP THE ONE WITH A MISSING ZIP CODE
  drop dup
  duplicates tag id year, gen(dup)
  drop if dup == 1 & zip == .
  
  *IN ONE ID FOR 2006 THERE ARE TWO ZIP CODES --> SET TO MISSING
  replace zip_code = . if id == 9001312142 & year == 2006   // YEAR HARDCODE: 2006 single-id zip fix
  drop dup
  duplicates drop
  duplicates tag id year, gen(dup)
  tab dup
  drop dup

* ---- Build Katrina/Rita evacuee indicator (carry 2005 value forward to 2006) ----
  *KATRINA INDICATORS MISSING FOR 2006, SO PULL FROM 2005 DATA
  sort id year
  rename katrina katrina_code
  replace katrina_code = "" if katrina_code == " "
  replace status = "" if status == " "
  label variable katrina_code "location code for Katrina\Rita students"
  gen katrina = katrina_code != ""
  tsset (id) year
  replace katrina = l.katrina if year == 2006 & l.katrina != .   // YEAR HARDCODE: carry 2005 evacuee flag into 2006
  label variable katrina "indicator for whether student was an evacuee due to Hurricanes Katrina or Rita"
  replace katrina = . if year < 2005   // YEAR HARDCODE: pre-treatment years have no evacuee status

* ---- Days each evacuee stayed in HISD during 2005 ----
  *GENERATE HOW LONG KATRINA STUDENTS STAYED IN HISD THROUGH 2005
  gen katrina_timeinhisd = date(leave, "MD20Y") - date(enter, "MD20Y") if year == 2005 & katrina == 1   // YEAR HARDCODE: 2005 dwell time
  replace katrina_timeinhisd = 9999 if katrina == 1 & year == 2005 & leave == "000000"   // YEAR HARDCODE: 9999 = stayed all year
  label variable katrina_timeinhisd "number of days evacuees spend in HISD in 2005 --> 9999 - stayed until end of yr"

  *DROP ETHNICITY, GENDER, LUNCH, DOB --> USE DEMOGRAPHIC FILE
  drop ethnicity gender lunch dob
  sort id year

  *RENAME DAYS ENROLLED, PRESENT, ABSENT
  rename t_days_t days_enrolled
  rename t_days_p days_present
  rename t_days_a days_absent

* ---- Save cleaned attendance file (input to merge_c.do) ----
save "C:\D\Research\Charter\Houston\HISDdata\DataFiles\2007_additions\attend_zip_katrina.dta", replace   // PATH: repoint to your local globals

