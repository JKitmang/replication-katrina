*===============================================================================
* FILE:     extra_stuff.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Auxiliary / scratch (Louisiana) -- NOT a numbered table on its own
* PRODUCES: Miscellaneous numbers, correlations, histograms, and supplementary
*           regressions cited in the text / footnotes / referee responses for the
*           LA analysis. Treat as auxiliary scratch, not a primary table program.
*
* PURPOSE:  Collects "loose ends" for the revision on the Louisiana data: (1)
*           correlations of pre-Katrina native lagged achievement with evacuee
*           shares (and an any-evacuee dummy) at the student and school-grade
*           level, to check quasi-random placement; (2) histograms of residualized
*           evacuee shares by grade and by quartile; (3) supplementary 4x4
*           non-linear peer-effect regressions controlling for evacuee
*           characteristics (% black, % economically disadvantaged), written to
*           elem_extra.xls / midhigh_extra.xls via outreg2.
*
* INPUTS:   la_prepped_revisionFULL_SAMPLE.dta, alternative_standardization.dta,
*           discipline_prepped_microdata.dta, tanumbers06-09_prepped2.dta
*           (all under /work/i/imberman/imberman/la_data/)
* OUTPUTS:  temp.dta (intermediate); hist_*.gph graph files; elem_extra.xls and
*           midhigh_extra.xls (outreg2); correlation/regression output to the log.
*
* KEY STEPS:
*   - Load LA panel, merge alt-standardized scores, discipline, TA numbers.
*   - Build baseline quartiles, evacuee shares/counts, pre-Katrina lags.
*   - pwcorr of lagged native scores vs evacuee shares (student & school-grade).
*   - Residualize evacuee shares on lagged scores; draw histograms.
*   - areg 4x4 non-linear peer models w/ evacuee-characteristic controls -> xls.
*
* HARDCODED YEARS / PATHS TO UPDATE FOR A NEW-YEARS REPLICATION:
*   - PATHS: absolute /work/i/imberman/imberman/la_data/... on the `use`, every
*     `merge ... using`, and the outreg2 .xls targets -- repoint to local globals.
*   - Commented Windows path `D:\School\Katrina\LA DOE\Revision`.
*   - keep if year >= 2000 & year <= 2007; drop year==2006/2007 grade 4/5.
*   - lagsample thresholds: year>2001 (g10), year>2003 (g8), year>2005 (g6,7,9).
*   - replace math_lag/ela_lag = *0005 if year>2005 (lag forced pre-Katrina).
*   - replace ... = 0 if year<=2005 (pre-treatment shares/counts = 0).
*   - forvalues year = 2000/2005 loop reconstructing lag year; year>2005 guards.
*   - if year == 2006 filters on every pwcorr / collapse / histogram block.
*
* NOTE: Documentation comments only -- no executable code was modified.
*===============================================================================
***SOME ADDITIONAL LOOSE ENDS FOR THE REVISION***

clear
set mem 8g
set more off

*********LA********
* ---- SCORE STANDARDIZATION: alternative procedure anchored to 2003-04 scale scores ----
********THIS PROGRAM USES AN ALTERNATIVE STANDARDIZATION PROCEDURE THAT STANDARDIZES BASED ON MEAN SCALE SCORES IN 2003-04 FOR ALL YEARS****
********SINCE TESTING ONLY DONE IN GRADES 4, 8 & 10 IN THIS YEAR, USE GRADE 4 MEAN AND SD FOR GRADES 3 - 5, GRADE 8 FOR 6 - 8, AND GRADE 10 FOR 9
******** & 10

* 7.14.10  we switched to using the entire data set...so recode as 0 ( iei non-katrina all students who were never in a Katrina or Rita district)

* 6.24.10 I prepped the TA (test administrator numbers) for 2006-2009...and merge in...test the bad apple model

* 4/22/10  I switched to using scaled scores, try lagged dependent variable on rhs..I've updated the lag to use data back to 2000

* run it with and without lagged dependent
* run it defining percent katrina at school*year and school*year*grade level


* for the lagged dependent variable (math_lag and ela_lag) , I start with the most recent lag.  I then insist that the lag be a pre-katrina score...so in 2007 I allow a 2006 score to be the lag

* for the quartiles of katrina kids performance I use the most recent test score 

* one remaining issue is how I classify non-evacuees into quartiles...I previously used 2000-2005 data which is a little wierd bc those years are also included in the regression

* now I predict math and ela scores and sort into quartiles off predicted values

clear
set mem 1900m
capture log close

set seed 10563

*cd "D:\School\Katrina\LA DOE\Revision"
*log using la_log2_quartiles, text replace

* 6.14 try another run in which I use the true lag rather than capping at 2005 
set more off


* ---- Load LA master panel ----
use /work/i/imberman/imberman/la_data/la_prepped_revisionFULL_SAMPLE.dta   // PATH: repoint to your local globals
* sample 3

drop  gender district_name school_name birth_month birth_day birth_year ela_raw math_raw sci_raw sci_scale scienceachievement soc_raw soc_scale ethnicity00_03 special_ed spec_ed2 school_type home_school ela_numcorrect sci_numcorrect ela_test_status math_test_status sci_test_status soc_test_status ela_achieve math_achieve social_achieve mathMEAN mathSD elaMEAN elaSD neworleans_returning_school neworleans_evacueedistrict new_orleans_area


*MERGE IN ALTERNATIVELY STANDARDIZED ACHIEVEMENT DATA
drop *STD *_lag *_lagyear *0005 math200* ela200*
sort id year
merge id year using /work/i/imberman/imberman/la_data/alternative_standardization.dta   // PATH: repoint locally
drop _merge

* ---- BASELINE ACHIEVEMENT QUARTILES: built within grade-year from *0005 score ----
* fix the quartile analysis...calculate within each year rather than limiting to 2006

capture drop mathQUART elaQUART
capture drop mathQUARTa elaQUARTa

bysort grade_num year: quantiles math0005, gen(mathQUART) nq(4) stable   // baseline achievement quartiles (math)
bysort grade_num year: quantiles ela0005, gen(elaQUART) nq(4) stable     // baseline achievement quartiles (ela)

capture drop mathQD*
capture drop elaQD*

tab mathQUART, gen(mathQD)
tab elaQUART, gen(elaQD)



* ---- Grade/year sample restrictions ----
*MAKE GRADE/YEAR RESTRICTIONS

keep if year >= 2000 & year <= 2007   // YEAR HARDCODE: analysis window; widen for new years
keep if grade_num >= 4 & grade_num <= 10
drop if year == 2006 & grade_num == 4   // YEAR HARDCODE: grade-year not tested/available
drop if year == 2007 & grade_num == 4   // YEAR HARDCODE
drop if year == 2007 & grade_num == 5   // YEAR HARDCODE


* ---- Identify the lag sample (grades with a usable pre-Katrina lagged score) ----
*IDENTIFY THE LAG SAMPLE
gen lagsample = 0
replace lagsample = 1 if year > 2001 & grade_num == 10   // YEAR HARDCODE: lag available
replace lagsample = 1 if year > 2003 & grade_num == 8     // YEAR HARDCODE
replace lagsample = 1 if year > 2005 & (grade_num == 6 | grade_num == 7 | grade_num == 9)   // YEAR HARDCODE



summ mathSTD elaSTD

tab year
*********************************************************************
* drop all the old grade year interactions and use gradenum instead
*********************************************************************


drop gryr*


xi i.grade_num*i.year, prefix(gryr)


* make the lags all pre-katrina scores
* it is the most recent lag but always pre-katrina
* save originals as math_lag2 and ela_lag2

* ---- Force lagged scores to be pre-Katrina (most recent pre-2006 score) ----
gen math_lag2=math_lag
gen ela_lag2=ela_lag
replace math_lag=math0005 if year>2005   // YEAR HARDCODE: post-Katrina lag <- pre-Katrina composite
replace ela_lag=ela0005 if year>2005     // YEAR HARDCODE


* ---- Baseline (2003/2004) score for sorting students into quartiles ----
* get baseline score for sorting students
gen math0004=math2004                                    // YEAR HARDCODE: 2004 baseline score
replace math0004=math2003 if math0004==. & math2003!=.   // YEAR HARDCODE: fall back to 2003
* replace math0004=math2002 if math0004==. & math2002!=.
* replace math0004=math2001 if math0004==. & math2001!=.
* replace math0004=math2000 if math0004==. & math2000!=.
bysort grade_num year: quantiles math0004 , gen(math_0004QUART) nq(4) stable

gen ela0004=ela2004
replace ela0004=ela2003 if ela0004==. & ela2003!=.
* replace ela0004=ela2002 if ela0004==. & ela2002!=.
* replace ela0004=ela2001 if ela0004==. & ela2001!=.
* replace ela0004=ela2000 if ela0004==. & ela2000!=.
bysort grade_num year: quantiles ela0004 , gen(ela_0004QUART) nq(4) stable





* make 2005 and all its interactions with each grade the ommitted category
*drop gryr*_2005


***********************************
* merge in the discipline data
***********************************
capture drop _m
sort id year

merge id year, using /work/i/imberman/imberman/la_data/discipline_prepped_microdata   // PATH: repoint locally

tab _m

drop if _m==2


***********************************
* merge in the test administrator data
***********************************
capture drop _m
sort id year

merge id year, using /work/i/imberman/imberman/la_data/tanumbers06-09_prepped2.dta   // PATH: repoint locally

tab _m

drop if _m==2


summ mathSTD elaSTD

tab year



* identify my class using TA numbers

egen class=group(sitecode year elamthtanumber)

***********************************
* recode the discipline data: missing means no discpline record for that student
***********************************
rename discpline_any discipline_any
recode discipline_any .=0

recode  disciplinedaycnt .=0

recode free_lunchA .=0 3=.

* define a dummy for cameron and calcasiu parishes

gen cameron_calcasieu=0
replace cameron_calcasieu=1 if district_code==10 | district_code==12



* redefine katrina_district2 so that cameron and calcasieu districts are also excluded in the peer effects regressions

replace katrina_district2=1 if cameron_calcasieu==1


* ---- Define evacuee (Rita/Katrina) shares; zero in pre-treatment years ----
* define percent Rita

egen percent_ritaTIMESERIES2=mean(rita), by(district_code school_code year)
replace percent_ritaTIMESERIES2=0 if year<=2005   // YEAR HARDCODE: no evacuees before 2005-06


***********************************************
***********************************************

***************************
* redefine percent katrina
****************************
***********************************************
***********************************************
***********************************************

* create katrina_district3 which is a variable for EVER being in a katrina district

egen katrina_district3=max(katrina_district2), by(id)

replace katrina_district3=0 if katrina_district3==.

** do it within school and grade and class 
** include the Rita kids as katrina kids

capture drop percent_katrinaTIMESERIES2

**
replace katrina_sum=1 if rita==1

* make kids with missing katrina_sum 0 if katrina_district3 is 0

replace katrina_sum=0 if katrina_sum==. & katrina_district3==0

* evacuee share at school-year and school-year-grade level; 0 in all pre-2005-06 years
egen percent_katrinaTIMESERIES2=mean(katrina_sum), by(district_code school_code year)
replace percent_katrinaTIMESERIES2=0 if year<=2005   // YEAR HARDCODE: pre-treatment evacuee share = 0


egen percent_katrinaTIMESERIESG=mean(katrina_sum), by(district_code school_code year grade_num)
replace percent_katrinaTIMESERIESG=0 if year<=2005   // YEAR HARDCODE

*GENERATE COUNTS BY GRADE
egen katrina_number_grade = sum(katrina_sum), by(district_code school_code year grade_num)
replace katrina_number_grade = 0 if year <= 2005   // YEAR HARDCODE: zero evacuee count pre-2005-06
gen unit = 1
egen enroll_grade = sum(unit), by(district_code school_code year grade_num)


* gen white=(black==0 & asian==0 & hisp==0)

* gen grade_num=real(grade)



***************************
* define katrina peer averages of discplined vs not
****************************

gen discipline05a=discipline_any if year==2005

egen discipline05=max(discipline05a), by(id)

egen percent_katrinaDISCIPLINE2=mean(katrina_sum*discipline05), by(district_code school_code year)
replace percent_katrinaDISCIPLINE2=0 if year<=2005


* count the number of katrina kids in my class
egen count_katrinaDISCIPLINE_class=sum(katrina_sum*discipline05), by(class)
replace count_katrinaDISCIPLINE_class=. if sitecode==. | elamth==.

egen count_katrina_class=sum(katrina_sum), by(class)
replace count_katrina_class=. if sitecode==. | elamth==.


**********************
* determine if we see a student two years in a row and whether or not they have switched schools

* non switchers are those observed two consecutive years and have the same school code both times
capture drop switch

sort id year
gen switch =0 if id==id[_n-1] & year==year[_n-1]+1 & sitecode==sitecode[_n-1] & sitecode!=.
replace switch =1 if id==id[_n-1] & year==year[_n-1]+1 & sitecode!=sitecode[_n-1] & sitecode!=.








* get fraction of all peers who are in each quartile
egen fraction_mathQ1=mean(mathQD1), by(district_code school_code year)
egen fraction_mathQ2=mean(mathQD2), by(district_code school_code year)
egen fraction_mathQ3=mean(mathQD3), by(district_code school_code year)
egen fraction_mathQ4=mean(mathQD4), by(district_code school_code year)


egen fraction_elaQ1=mean(elaQD1), by(district_code school_code year)
egen fraction_elaQ2=mean(elaQD2), by(district_code school_code year)
egen fraction_elaQ3=mean(elaQD3), by(district_code school_code year)
egen fraction_elaQ4=mean(elaQD4), by(district_code school_code year)





* get fraction of katrina peers who are in each quartile

egen Kfraction_mathQ1=mean(mathQD1*katrina_sum), by(district_code school_code year)
egen Kfraction_mathQ2=mean(mathQD2*katrina_sum), by(district_code school_code year)
egen Kfraction_mathQ3=mean(mathQD3*katrina_sum), by(district_code school_code year)
egen Kfraction_mathQ4=mean(mathQD4*katrina_sum), by(district_code school_code year)


egen Kfraction_elaQ1=mean(elaQD1*katrina_sum), by(district_code school_code year)
egen Kfraction_elaQ2=mean(elaQD2*katrina_sum), by(district_code school_code year)
egen Kfraction_elaQ3=mean(elaQD3*katrina_sum), by(district_code school_code year)
egen Kfraction_elaQ4=mean(elaQD4*katrina_sum), by(district_code school_code year)





replace Kfraction_mathQ1=0 if year<=2005
replace Kfraction_mathQ2=0 if year<=2005
replace Kfraction_mathQ3=0 if year<=2005
replace Kfraction_mathQ4=0 if year<=2005

replace Kfraction_elaQ1=0 if year<=2005
replace Kfraction_elaQ2=0 if year<=2005
replace Kfraction_elaQ3=0 if year<=2005
replace Kfraction_elaQ4=0 if year<=2005






** Now calculate the fraction of katrina peers within each school district code and gradenum

* get fraction of katrina peers who are in each quartile

egen Kfraction_mathQ1G=mean(mathQD1*katrina_sum), by(district_code school_code year grade_num)
egen Kfraction_mathQ2G=mean(mathQD2*katrina_sum), by(district_code school_code year grade_num)
egen Kfraction_mathQ3G=mean(mathQD3*katrina_sum), by(district_code school_code year grade_num)
egen Kfraction_mathQ4G=mean(mathQD4*katrina_sum), by(district_code school_code year grade_num)


egen Kfraction_elaQ1G=mean(elaQD1*katrina_sum), by(district_code school_code year grade_num)
egen Kfraction_elaQ2G=mean(elaQD2*katrina_sum), by(district_code school_code year grade_num)
egen Kfraction_elaQ3G=mean(elaQD3*katrina_sum), by(district_code school_code year grade_num)
egen Kfraction_elaQ4G=mean(elaQD4*katrina_sum), by(district_code school_code year grade_num)


egen Knumber_mathQ1G = sum(mathQD1*katrina_sum), by(district_code school_code year grade_num)
egen Knumber_mathQ2G = sum(mathQD2*katrina_sum), by(district_code school_code year grade_num)
egen Knumber_mathQ3G = sum(mathQD3*katrina_sum), by(district_code school_code year grade_num)
egen Knumber_mathQ4G = sum(mathQD4*katrina_sum), by(district_code school_code year grade_num)


egen Knumber_elaQ1G = sum(elaQD1*katrina_sum), by(district_code school_code year grade_num)
egen Knumber_elaQ2G = sum(elaQD2*katrina_sum), by(district_code school_code year grade_num)
egen Knumber_elaQ3G = sum(elaQD3*katrina_sum), by(district_code school_code year grade_num)
egen Knumber_elaQ4G = sum(elaQD4*katrina_sum), by(district_code school_code year grade_num)


replace Kfraction_mathQ1G=0 if year<=2005
replace Kfraction_mathQ2G=0 if year<=2005
replace Kfraction_mathQ3G=0 if year<=2005
replace Kfraction_mathQ4G=0 if year<=2005

replace Kfraction_elaQ1G=0 if year<=2005
replace Kfraction_elaQ2G=0 if year<=2005
replace Kfraction_elaQ3G=0 if year<=2005
replace Kfraction_elaQ4G=0 if year<=2005



replace Knumber_mathQ1G=0 if year<=2005
replace Knumber_mathQ2G=0 if year<=2005
replace Knumber_mathQ3G=0 if year<=2005
replace Knumber_mathQ4G=0 if year<=2005

replace Knumber_elaQ1G=0 if year<=2005
replace Knumber_elaQ2G=0 if year<=2005
replace Knumber_elaQ3G=0 if year<=2005
replace Knumber_elaQ4G=0 if year<=2005


egen Tnumber_mathQ1G = sum(mathQD1*unit), by(district_code school_code year grade_num)
egen Tnumber_mathQ2G = sum(mathQD2*unit), by(district_code school_code year grade_num)
egen Tnumber_mathQ3G = sum(mathQD3*unit), by(district_code school_code year grade_num)
egen Tnumber_mathQ4G = sum(mathQD4*unit), by(district_code school_code year grade_num)


egen Tnumber_elaQ1G = sum(elaQD1*unit), by(district_code school_code year grade_num)
egen Tnumber_elaQ2G = sum(elaQD2*unit), by(district_code school_code year grade_num)
egen Tnumber_elaQ3G = sum(elaQD3*unit), by(district_code school_code year grade_num)
egen Tnumber_elaQ4G = sum(elaQD4*unit), by(district_code school_code year grade_num)



foreach var of varlist enroll_grade Tnumber_* {
  gen `var'_2 = `var'^2
  gen `var'_3 = `var'^3
  gen `var'_4 = `var'^4
}

*****************************************************
** Calculate percent Katrina at the Classroom Level
*****************************************************
*****************************************************

* get fraction of katrina peers who are in each quartile

egen Kfraction_mathQ1C=mean(mathQD1*katrina_sum), by(class)
egen Kfraction_mathQ2C=mean(mathQD2*katrina_sum), by(class)
egen Kfraction_mathQ3C=mean(mathQD3*katrina_sum), by(class)
egen Kfraction_mathQ4C=mean(mathQD4*katrina_sum), by(class)


egen Kfraction_elaQ1C=mean(elaQD1*katrina_sum), by(class)
egen Kfraction_elaQ2C=mean(elaQD2*katrina_sum), by(class)
egen Kfraction_elaQ3C=mean(elaQD3*katrina_sum), by(class)
egen Kfraction_elaQ4C=mean(elaQD4*katrina_sum), by(class)


replace Kfraction_mathQ1C=0 if year<=2005
replace Kfraction_mathQ2C=0 if year<=2005
replace Kfraction_mathQ3C=0 if year<=2005
replace Kfraction_mathQ4C=0 if year<=2005

replace Kfraction_elaQ1C=0 if year<=2005
replace Kfraction_elaQ2C=0 if year<=2005
replace Kfraction_elaQ3C=0 if year<=2005
replace Kfraction_elaQ4C=0 if year<=2005





**************
** try interacting lag with number of years between now and lag
**************
* ---- Reconstruct the lag YEAR for post-Katrina obs (which year the lag came from) ----
gen math_lagyear2=math_lagyear
gen ela_lagyear2=ela_lagyear

replace math_lagyear = . if year > 2005   // YEAR HARDCODE
replace ela_lagyear = . if year > 2005    // YEAR HARDCODE
forvalues year = 2000/2005 {              // YEAR HARDCODE: scan candidate pre-Katrina lag years
  replace math_lagyear = `year' if math0005 == math`year' & math_lag != . & year > 2005   // YEAR HARDCODE
  replace ela_lagyear = `year' if ela0005 == ela`year' & ela_lag != . & year > 2005       // YEAR HARDCODE
}

gen year_gap=year-math_lagyear
tab year_gap, gen(year_gapD)


gen year_gapE=year-ela_lagyear
tab year_gapE, gen(year_gapED)



gen math_lag_1=math_lag*year_gapD1
gen math_lag_2=math_lag*year_gapD2
gen math_lag_3=math_lag*year_gapD3
gen math_lag_4=math_lag*year_gapD4
gen math_lag_5=math_lag*year_gapD5
gen math_lag_6=math_lag*year_gapD6
gen math_lag_7=math_lag*year_gapD7



gen ela_lag_1=ela_lag*year_gapED1
gen ela_lag_2=ela_lag*year_gapED2
gen ela_lag_3=ela_lag*year_gapED3
gen ela_lag_4=ela_lag*year_gapED4
gen ela_lag_5=ela_lag*year_gapED5
gen ela_lag_6=ela_lag*year_gapED6
gen ela_lag_7=ela_lag*year_gapED7


* ---- Evacuee-characteristic controls (share black / FRP) by school-grade-year ----
*GENERATE EVAC CHARS IN SCHOOL
egen evac_blacka = mean(black) if katrina_sum == 1, by(sitecode grade year)
egen evac_black = max(evac_blacka), by(sitecode grade year)
replace evac_black = 0 if evac_black == . | year <= 2005   // YEAR HARDCODE: zero pre-2005-06

egen evac_frpa = mean(free_lunchA) if katrina_sum == 1, by(sitecode grade year)
egen evac_frp = max(evac_frpa), by(sitecode grade year)
replace evac_frp = 0 if evac_frp == . | year <= 2005


* ---- Estimation sample: native (non-evacuee) students, non-evac districts, share<.7 ----
*RESTRICT TO NON-EVACUEES IN SCHOOLS THAT WERE NOT IN EVAC AREA
keep if katrina_sum != 1 & katrina_district2==0 & percent_katrina<.7



* ===========================================================================
* ---- AUX: correlations of pre-Katrina native lag scores with evacuee shares ----
* (quasi-random-placement check, restricted to year==2006, student level)
* ===========================================================================
***CORRELATIONS OF PRE-KATRINA NATIVE SCORES WITH EVACUEE SHARES AND HAVING ANY EVACUEES IN SCHOOL


gen anyevac_school = percent_katrinaTIMESERIES2 > 0 if percent_katrinaTIMESERIES2 != .
gen anyevac_grade = percent_katrinaTIMESERIESG > 0 if percent_katrinaTIMESERIESG != .

*ELEM   // pwcorr filtered to year==2006 throughout this block  // YEAR HARDCODE
pwcorr math_lag percent_katrinaTIMESERIES2 if year == 2006 &  mathQD1 != . & grade_num<=5 & percent_katrinaTIMESERIES2 > 0, sig
pwcorr math_lag anyevac_school if year == 2006 &  mathQD1 != . & grade_num<=5, sig
pwcorr math_lag percent_katrinaTIMESERIESG if year == 2006 &  mathQD1 != . & grade_num<=5  & percent_katrinaTIMESERIESG > 0, sig
pwcorr math_lag anyevac_grade if year == 2006 &  mathQD1 != . & grade_num<=5, sig

pwcorr ela_lag percent_katrinaTIMESERIES2 if year == 2006 &  elaQD1 != . & grade_num<=5  & percent_katrinaTIMESERIES2 > 0, sig
pwcorr ela_lag anyevac_school if year == 2006 &  elaQD1 != . & grade_num<=5, sig
pwcorr ela_lag percent_katrinaTIMESERIESG if year == 2006 &  elaQD1 != . & grade_num<=5  & percent_katrinaTIMESERIESG > 0, sig
pwcorr ela_lag anyevac_grade if year == 2006 &  elaQD1 != . & grade_num<=5, sig



*MIDHIGH
pwcorr math_lag percent_katrinaTIMESERIES2 if year == 2006 &  mathQD1 != . & grade_num>5  & percent_katrinaTIMESERIES2 > 0, sig
pwcorr math_lag anyevac_school if year == 2006 &  mathQD1 != . & grade_num>5, sig
pwcorr math_lag percent_katrinaTIMESERIESG if year == 2006 &  mathQD1 != . & grade_num>5  & percent_katrinaTIMESERIESG > 0, sig
pwcorr math_lag anyevac_grade if year == 2006 &  mathQD1 != . & grade_num>5, sig

pwcorr ela_lag percent_katrinaTIMESERIES2 if year == 2006 &  elaQD1 != . & grade_num>5  & percent_katrinaTIMESERIES2 > 0, sig
pwcorr ela_lag anyevac_school if year == 2006 &  elaQD1 != . & grade_num>5, sig
pwcorr ela_lag percent_katrinaTIMESERIESG if year == 2006 &  elaQD1 != . & grade_num>5  & percent_katrinaTIMESERIESG > 0, sig
pwcorr ela_lag anyevac_grade if year == 2006 &  elaQD1 != . & grade_num>5, sig


save temp, replace

* ---- AUX: same correlations collapsed to school-grade level (math) ----
****CORRS AT SCHOOL-GRADE LEVEL - MATH
keep if mathQD1 != .
collapse (mean) math_lag ela_lag percent_katrina* anyevac_*, by(sitecode year grade_num)


*ELEM
pwcorr math_lag percent_katrinaTIMESERIES2 if year == 2006 & grade_num<=5 & percent_katrinaTIMESERIES2 > 0, sig
pwcorr math_lag anyevac_school if year == 2006 & grade_num<=5, sig
pwcorr math_lag percent_katrinaTIMESERIESG if year == 2006 & grade_num<=5  & percent_katrinaTIMESERIESG > 0, sig
pwcorr math_lag anyevac_grade if year == 2006 & grade_num<=5, sig


*MIDHIGH
pwcorr math_lag percent_katrinaTIMESERIES2 if year == 2006 & grade_num>5  & percent_katrinaTIMESERIES2 > 0, sig
pwcorr math_lag anyevac_school if year == 2006 & grade_num>5, sig
pwcorr math_lag percent_katrinaTIMESERIESG if year == 2006 & grade_num>5  & percent_katrinaTIMESERIESG > 0, sig
pwcorr math_lag anyevac_grade if year == 2006 & grade_num>5, sig


* ---- AUX: same correlations collapsed to school-grade level (ELA) ----
***CORRS AT SCHOOL-GRADE LEVEL - ELA
use temp, clear
keep if elaQD1 != .
collapse (mean) math_lag ela_lag percent_katrina* anyevac_*, by(sitecode year grade_num)


pwcorr ela_lag percent_katrinaTIMESERIES2 if year == 2006 & grade_num<=5  & percent_katrinaTIMESERIES2 > 0, sig
pwcorr ela_lag anyevac_school if year == 2006 & grade_num<=5, sig
pwcorr ela_lag percent_katrinaTIMESERIESG if year == 2006 & grade_num<=5  & percent_katrinaTIMESERIESG > 0, sig
pwcorr ela_lag anyevac_grade if year == 2006 & grade_num<=5, sig



pwcorr ela_lag percent_katrinaTIMESERIES2 if year == 2006 & grade_num>5  & percent_katrinaTIMESERIES2 > 0, sig
pwcorr ela_lag anyevac_school if year == 2006 & grade_num>5, sig
pwcorr ela_lag percent_katrinaTIMESERIESG if year == 2006 & grade_num>5  & percent_katrinaTIMESERIESG > 0, sig
pwcorr ela_lag anyevac_grade if year == 2006 & grade_num>5, sig

f
* ===========================================================================
* ---- AUX: histograms of residualized evacuee shares (2005-06 only) ----
* residualize evacuee shares on lagged native scores, then plot by grade/quartile
* ===========================================================================
***HISTOGRAM OF EVACUEE SHARES BY SCHOOL AFTER REMOVING VARIATION FROM LAGGED NATIVE ACHIEVEMENT

use temp, clear

  ***KEEP 2005-06 ONLY
  keep if year == 2006   // YEAR HARDCODE: first post-Katrina year only

  ***COLLAPSE TO SCHOOL-GRADE-LEVEL DATASET
  collapse (mean) percent_katrinaTIMESERIESG Kfraction*G math_lag ela_lag, by (sitecode grade)
  foreach var of varlist percent_katrinaTIMESERIESG Kfraction*G {
	reg `var' math_lag ela_lag 
 	predict `var'_res, resid
  }

  *GENERATE HISTOGRAMS --> FIRST FOR ALL SCHOOLS
  hist percent_katrinaTIMESERIESG_res, width(.01) saving(hist_all_all.gph, replace) xtitle("Residual Evacuee Share in Grade") ytitle("Density")
  hist Kfraction_mathQ1G_res, width(.01) saving(hist_math1_all.gph, replace) xtitle("Residual Evacuee Share in Grade - 1st Quartile Math") ytitle("Density")
  hist Kfraction_mathQ2G_res, width(.01) saving(hist_math2_all.gph, replace) xtitle("Residual Evacuee Share in Grade - 2nd Quartile Math") ytitle("Density")
  hist Kfraction_mathQ3G_res, width(.01) saving(hist_math3_all.gph, replace) xtitle("Residual Evacuee Share in Grade - 3rd Quartile Math") ytitle("Density")
  hist Kfraction_mathQ4G_res, width(.01) saving(hist_math4_all.gph, replace) xtitle("Residual Evacuee Share in Grade - 4th Quartile Math") ytitle("Density")
  hist Kfraction_elaQ1G_res, width(.01) saving(hist_ela1_all.gph, replace) xtitle("Residual Evacuee Share in Grade - 1st Quartile ELA") ytitle("Density")
  hist Kfraction_elaQ2G_res, width(.01) saving(hist_ela2_all.gph, replace) xtitle("Residual Evacuee Share in Grade - 2nd Quartile ELA") ytitle("Density")
  hist Kfraction_elaQ3G_res, width(.01) saving(hist_ela3_all.gph, replace) xtitle("Residual Evacuee Share in Grade - 3rd Quartile ELA") ytitle("Density")
  hist Kfraction_elaQ4G_res, width(.01) saving(hist_ela4_all.gph, replace) xtitle("Residual Evacuee Share in Grade - 4th Quartile ELA") ytitle("Density")

  *SECOND --> FOR GRADES WITH POSITIVE EVACUEE SHARE
  hist percent_katrinaTIMESERIESG_res if percent_katrinaTIMESERIESG > 0, width(.01) saving(hist1_pos.gph, replace) xtitle("Residual Evacuee Share in Grade") ytitle("Density")
  hist Kfraction_mathQ1G_res if Kfraction_mathQ1G > 0, width(.01) saving(hist_math1_pos.gph, replace) xtitle("Residual Evacuee Share in Grade - 1st Quartile Math") ytitle("Density")
  hist Kfraction_mathQ2G_res if Kfraction_mathQ2G >0, width(.01) saving(hist_math2_pos.gph, replace) xtitle("Residual Evacuee Share in Grade - 2nd Quartile Math") ytitle("Density")
  hist Kfraction_mathQ3G_res if Kfraction_mathQ3G >0, width(.01) saving(hist_math3_pos.gph, replace) xtitle("Residual Evacuee Share in Grade - 3rd Quartile Math") ytitle("Density")
  hist Kfraction_mathQ4G_res if Kfraction_mathQ4G >0, width(.01) saving(hist_math4_pos.gph, replace) xtitle("Residual Evacuee Share in Grade - 4th Quartile Math") ytitle("Density")
  hist Kfraction_elaQ1G_res if Kfraction_elaQ1G >0, width(.01) saving(hist_ela1_pos.gph, replace) xtitle("Residual Evacuee Share in Grade - 1st Quartile ELA") ytitle("Density")
  hist Kfraction_elaQ2G_res if Kfraction_elaQ2G >0, width(.01) saving(hist_ela2_pos.gph, replace) xtitle("Residual Evacuee Share in Grade - 2nd Quartile ELA") ytitle("Density")
  hist Kfraction_elaQ3G_res if Kfraction_elaQ3G >0, width(.01) saving(hist_ela3_pos.gph, replace) xtitle("Residual Evacuee Share in Grade - 3rd Quartile ELA") ytitle("Density")
  hist Kfraction_elaQ4G_res if Kfraction_elaQ4G >0, width(.01) saving(hist_ela4_pos.gph, replace) xtitle("Residual Evacuee Share in Grade - 4th Quartile ELA") ytitle("Density")


use temp, clear

* ===========================================================================
* ---- AUX: 4x4 non-linear peer models w/ evacuee-characteristic controls ----
* (% evacuees black, % evacuees economically disadvantaged); outreg2 -> .xls
* ===========================================================================
*RUN 4X4 MODELS WITH CONTROLS FOR %OF EVACUEES WHO ARE BLACK & %OF EVACUEES WHO ARE ECONOMICALLY DISADVANTAGED

capture rm elem_extra.txt
capture rm elem_extra.xls

*Elementary SAMPLE (NO LAG)

areg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* evac_black evac_frp if mathQD1 != . & grade_num<=5   , absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/elem_extra.xls, excel dec(2) ctitle("Math, Non-Linear, All, control for evac chars")   // PATH: repoint .xls target locally


areg elaSTD Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* evac_black evac_frp if elaQD1 != . & grade_num<=5   , absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/elem_extra.xls, excel dec(2) ctitle("ELA, Non-Linear, All, control for evac chars")


*LAG SAMPLE (WITH LAGS - 2002 & LATER, MIDHIGH ONLY)

areg mathSTD math_lag_* Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* evac_black evac_frp if lagsample == 1 & mathQD1 != .   , absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/midhigh_extra.xls, excel dec(2) ctitle("Math, Non-Linear, All, control for evac chars")

areg elaSTD ela_lag_* Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* evac_black evac_frp if lagsample == 1 & elaQD1 != .   , absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/midhigh_extra.xls, excel dec(2) ctitle("ELA, Non-Linear, All, control for evac chars")

forvalues quart = 1/4 {

di ""
di "****************"
di "QUARTILE `quart'"
di "****************"
di ""

*Elementary SAMPLE (NO LAG)

areg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* evac_black evac_frp if mathQD`quart' == 1 & grade_num<=5    , absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/elem_extra.xls, excel dec(2) ctitle("Math, Non-Linear, Quartile `quart', control for evac chars")

areg elaSTD Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* evac_black evac_frp if elaQD`quart' == 1 & grade_num<=5   , absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/elem_extra.xls, excel dec(2) ctitle("ELA, Non-Linear, Quartile `quart', control for evac chars")


*LAG SAMPLE (WITH LAGS - 2002 & LATER, MIDHIGH ONLY)

areg mathSTD math_lag_* Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* evac_black evac_frp if lagsample == 1 & mathQD`quart' == 1   , absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/midhigh_extra.xls, excel dec(2) ctitle("Math, Non-Linear, Quartile `quart', control for evac chars")

areg elaSTD ela_lag_* Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* evac_black evac_frp if lagsample == 1 & elaQD`quart' == 1   , absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/midhigh_extra.xls, excel dec(2) ctitle("ELA, Non-Linear, Quartile `quart', control for evac chars")
}



