*===============================================================================
* FILE:     school_level_placebo_b.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Analysis (Louisiana school-level placebo test)
* PRODUCES: Table 9 and App Tables 25-26 (school-level SPS placebo regressions).
*
* PURPOSE:  Companion to school-trend.do. Reads LA Department of Education
*           school-level "School Performance Score" (SPS) reports for 1999-2005,
*           shifts each report forward by two years (year = year + 2) so the
*           PRE-Katrina SPS lines up with the post-Katrina school x year evacuee
*           shares, merges in those shares, and regresses (lagged) SPS on the
*           evacuee share. This is a placebo: a school's future evacuee share
*           should not predict its earlier SPS once school FE are included.
*
* INPUTS:   1999.dta .. 2005.dta   (annual school-level SPS reports)
*           school_level_means.dta (school x year evacuee shares; from school_level_means.do)
* OUTPUTS:  None saved; regression output to the log (la_school_level_log).
*
* KEY STEPS:
*   - Append annual SPS report files 1999-2005.
*   - Shift report year forward by 2 (year = year + 2) to align lag with shares.
*   - Merge in evacuee shares; zero out shares for year<2004.
*   - Average math & ela quartile shares into Kfraction_Q1..Q4.
*   - Run school-FE (areg) placebo regressions of SPS on evacuee share +/- controls.
*
* HARDCODED YEARS / PATHS TO UPDATE FOR A NEW-YEARS REPLICATION:
*   - `cd "C:\katrina\sps"` absolute working directory (see PATH flag below).
*   - Annual SPS append list `use 1999.dta` ... `append using 2005.dta`.
*   - `replace year = year + 2` two-year placebo shift (re-derive for new windows).
*   - `replace `var' = 0 if year < 2004` evacuee shares zero before shifted-2004.
*   - No Sept-13 instrument here (this is the LA, not Houston, branch).
*
* NOTE: Documentation comments only — no executable code was modified.
*===============================================================================
* this reads in the school level reports on Student Performace Scores from LA website
* merges in percent katrina in 2006 to ask whether percent katrina is correlated with pre-levels or trends

* ---- Setup ----
clear
set mem 700m
capture log close



cd "C:\katrina\sps"   // PATH: repoint to your local globals

log using la_school_level_log, text replace
set more off




* ---- Append annual SPS report files 1999-2005 ----
use 1999.dta
gen year=1999   // YEAR HARDCODE: first SPS report year
append using 2000.dta
replace year=2000 if year==.

append using 2001.dta
replace year=2001 if year==.

append using 2002.dta
replace year=2002 if year==.

append using 2003.dta
replace year=2003 if year==.


append using 2004.dta
replace year=2004 if year==.

append using 2005.dta
replace year=2005 if year==.   // YEAR HARDCODE: last SPS report year


destring sitecode, force replace

* ---- Two-year placebo shift: align pre-Katrina SPS with post-Katrina shares ----
replace year = year + 2   // YEAR HARDCODE: shift report year +2 so lagged SPS lines up with evacuee shares
sort sitecode year

* ---- Merge in school x year evacuee shares ----
merge sitecode year using school_level_means, nokeep
keep if _merge == 3


foreach var of varlist percent_katrinaTIMESERIES2 Kfraction* {
  replace `var' = 0 if year < 2004   // YEAR HARDCODE: evacuee shares = 0 before (shifted) 2004
}


* ---- Average math & ela quartile shares into Kfraction_Q1..Q4 ----
*GENERATE AVERAGE OF MATH & ELA KFRACTION SHARES
egen Kfraction_Q1 = rmean(Kfraction_mathQ1 Kfraction_elaQ1)
egen Kfraction_Q2 = rmean(Kfraction_mathQ2 Kfraction_elaQ2)
egen Kfraction_Q3 = rmean(Kfraction_mathQ3 Kfraction_elaQ3)
egen Kfraction_Q4 = rmean(Kfraction_mathQ4 Kfraction_elaQ4)



* ---- School-FE placebo regressions of SPS on evacuee share (Table 9 / App 25-26) ----
xi i.year

* School FE: linear share, then quartile shares
areg sps percent_katrinaTIMESERIES2 _I* if Kfraction_Q1 != ., absorb(sitecode) cluster(sitecode)
areg sps Kfraction_Q1 Kfraction_Q2 Kfraction_Q3 Kfraction_Q4 _I*, absorb(sitecode) cluster(sitecode)


* School FE + demographic controls: linear share, then quartile shares
areg sps percent_katrinaTIMESERIES2 _I* free_lunchA male black hisp asian gryr* if Kfraction_Q1 != ., absorb(sitecode) cluster(sitecode)
areg sps Kfraction_Q1 Kfraction_Q2 Kfraction_Q3 Kfraction_Q4 _I* free_lunchA male black hisp asian gryr*, absorb(sitecode) cluster(sitecode)





log close

* ---- Below this point: scratch / unreachable (f, endsas;) — not executed by Stata ----
f







summ sps change_sps

by year,sort: summ sps change_sps


reg percent_katrinaTIMESERIES2 change_sps, robust 

endsas;
* areg sps percent_k
atrinaTIMESERIES2, absorb(sitecode) cluster(sitecode)








