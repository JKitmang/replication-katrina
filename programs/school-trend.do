*===============================================================================
* FILE:     school-trend.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Analysis (Louisiana school-level placebo/trend test)
* PRODUCES: Table 9 and App Tables 25-26 (school-level SPS trend regressions);
*           writes school_trend.xls via outreg2.
*
* PURPOSE:  Reads LA Department of Education school-level "School Performance
*           Score" (SPS) reports (2000-2005), fixes each school's 2006 evacuee
*           quartile shares as a time-invariant treatment, and asks whether the
*           evacuee share is correlated with a school's PRE-Katrina SPS LEVELS or
*           TRENDS. It interacts the (frozen 2006) evacuee shares with year dummies
*           and regresses pre-period SPS on those interactions — a placebo/trend
*           test that the share is not picking up pre-existing school trajectories.
*
* INPUTS:   school_level_means.dta (school x year evacuee shares; from school_level_means.do)
*           2000.dta .. 2005.dta   (annual school-level SPS reports)
* OUTPUTS:  school_means_oneyear.dta (frozen-2006 shares)
*           school_trend.xls / school_trend.txt (regression output)
*
* KEY STEPS:
*   - Freeze each school's 2006 evacuee shares (constant within sitecode).
*   - Append annual SPS files 2000-2005; merge on frozen shares.
*   - Average math & ela quartile shares into Kfraction_Q1..Q4.
*   - Interact shares with year dummies; run pooled, FE (areg), and FE+controls.
*
* HARDCODED YEARS / PATHS TO UPDATE FOR A NEW-YEARS REPLICATION:
*   - `cd "C:\katrina\sps"` absolute working directory (see PATH flag below).
*   - `if year == 2006` — 2006 is the post-Katrina year whose shares are frozen.
*   - Annual SPS append list `use 2000.dta` ... `append using 2005.dta` (pre-period).
*   - `year_2 ... year_6` year-dummy interaction loop (pre-period year dummies).
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

* ---- Freeze each school's 2006 evacuee shares as a time-invariant treatment ----
use school_level_means, clear
 foreach var of varlist Kfraction_* percent_katrina* {
   gen temp = `var' if year == 2006   // YEAR HARDCODE: 2006 = post-Katrina year whose evacuee shares are frozen
   egen temp2 = mean(temp), by (sitecode)
   replace `var' = temp2
   drop temp temp2
}
sort sitecode year
save school_means_oneyear, replace


* ---- Append annual SPS report files 2000-2005 (pre-period) ----
use 2000.dta
gen year=2000   // YEAR HARDCODE: first SPS report year

append using 2001.dta
replace year=2001 if year==.

append using 2002.dta
replace year=2002 if year==.

append using 2003.dta
replace year=2003 if year==.


append using 2004.dta
replace year=2004 if year==.

append using 2005.dta
replace year=2005 if year==.   // YEAR HARDCODE: last pre-Katrina SPS report year


destring sitecode, force replace

* ---- Merge frozen-2006 evacuee shares onto the pre-period SPS panel ----
sort sitecode year
merge sitecode year using school_means_oneyear, nokeep
keep if _merge == 3




* ---- Average math & ela quartile shares into Kfraction_Q1..Q4 ----
*GENERATE AVERAGE OF MATH & ELA KFRACTION SHARES
egen Kfraction_Q1 = rmean(Kfraction_mathQ1 Kfraction_elaQ1)
egen Kfraction_Q2 = rmean(Kfraction_mathQ2 Kfraction_elaQ2)
egen Kfraction_Q3 = rmean(Kfraction_mathQ3 Kfraction_elaQ3)
egen Kfraction_Q4 = rmean(Kfraction_mathQ4 Kfraction_elaQ4)

* ---- Interact (frozen) evacuee shares with year dummies for the trend test ----
tab year, gen(year_)

foreach var of varlist year_2 year_3 year_4 year_5 year_6 {   // YEAR HARDCODE: pre-period year dummies; year_1 omitted as base
  gen percent_katrina_`var' = percent_katrinaTIMESERIES2*`var'
  gen Kfraction_Q1_`var' = Kfraction_Q1*`var'
  gen Kfraction_Q2_`var' = Kfraction_Q2*`var'
  gen Kfraction_Q3_`var' = Kfraction_Q3*`var'
  gen Kfraction_Q4_`var' = Kfraction_Q4*`var'
}



* ---- Trend regressions of pre-period SPS on share x year interactions ----
* Output columns written to school_trend.xls feed Table 9 / App Tables 25-26.
xi i.year
cap rm school_trend.txt
cap rm school_trend.xls

* Pooled (no school FE): linear share, then quartile shares
reg sps percent_katrina_year_* _I* if Kfraction_Q1 != ., cluster(sitecode)
outreg2 percent_katrina* using school_trend.xls, excel dec(1)
reg sps Kfraction_Q1_year_* Kfraction_Q2_year_*  Kfraction_Q3_year_*  Kfraction_Q4_year_*  _I*, cluster(sitecode)
outreg2 Kfraction_* using school_trend.xls, excel dec(1)


* School FE (areg): linear share, then quartile shares
areg sps percent_katrina_year_* _I* if Kfraction_Q1 != ., absorb(sitecode) cluster(sitecode)
outreg2 percent_katrina* using school_trend.xls, excel dec(1)
areg sps Kfraction_Q1_year_* Kfraction_Q2_year_*  Kfraction_Q3_year_*  Kfraction_Q4_year_*  _I*, absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using school_trend.xls, excel dec(1)

* School FE + demographic controls: linear share, then quartile shares
areg sps percent_katrina_year_* _I* free_lunchA male black hisp asian gryr* if Kfraction_Q1 != ., absorb(sitecode) cluster(sitecode)
outreg2 percent_katrina_* using school_trend.xls, excel dec(1)

areg sps Kfraction_Q1_year_* Kfraction_Q2_year_*  Kfraction_Q3_year_*  Kfraction_Q4_year_*  _I* free_lunchA male black hisp asian gryr*, absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using school_trend.xls, excel dec(1)





log close

* ---- Below this point: scratch / unreachable (f, endsas;) — not executed by Stata ----
f







summ sps change_sps

by year,sort: summ sps change_sps


reg percent_katrinaTIMESERIES2 change_sps, robust 

endsas;
* areg sps percent_k
atrinaTIMESERIES2, absorb(sitecode) cluster(sitecode)








