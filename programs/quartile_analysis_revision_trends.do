*===============================================================================
* FILE:     quartile_analysis_revision_trends.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Robustness/variant (school-specific linear time-trend version of the
*           LA nonlinear quartile peer-effects analysis)
* PRODUCES: Appendix Tables 23 & 24 (per the dofile -> table map;
*           quartile_analysis_revision_full_trends_b family). Output panels:
*           "Full Trend" (school-specific trends over the whole window) and
*           "Partial Trend" (school trends zeroed out after Katrina).
*
* PURPOSE:  Re-runs the quartile-interacted evacuee-share regressions while
*           adding SCHOOL-SPECIFIC LINEAR TIME TRENDS (i.sitecode*year, the _I*
*           regressors) so that differential pre-existing school trends cannot
*           drive the estimated peer effects. The "partial trend" block sets the
*           school-trend terms to 0 in post-Katrina years (year>=2006) so the
*           trends are identified off pre-treatment data only. Note this variant
*           uses reg with cluster(sitecode) (school trends absorbed via dummies)
*           rather than areg with absorb(sitecode) as in revision_d.
*
* INPUTS:   /work/i/imberman/imberman/la_data/la_prepped_revision.dta  (NOTE:
*               this variant uses la_prepped_revision.dta, not the FULL_SAMPLE /
*               alternative-standardization inputs used by revision_d)
*           discipline_prepped_microdata.dta ; tanumbers06-09_prepped2.dta
*               (merged from the working dir set by the cd below)
* OUTPUTS:  outreg2 results: elem_trend.xls / midhigh_trend.xls (and the
*           elem_trends/midhigh_trends files removed at the top). No .dta saved.
*
* KEY STEPS:
*   - cd into the LA data dir; load la_prepped_revision.dta.
*   - Restrict years/grades; rebuild grade x year dummies and pre-Katrina lags.
*   - Build baseline achievement quartiles (own + evacuee peers) and evacuee
*     shares by quartile at school and grade levels.
*   - Generate school-specific linear trends (i.sitecode*year -> _I*).
*   - Run "Full Trend" battery, then zero post-2005 trend terms and run
*     "Partial Trend" battery; outreg2 each panel/column.
*
* HARDCODED YEARS / PATHS TO UPDATE FOR A NEW-YEARS REPLICATION:
*   - cd /work/i/imberman/imberman/la_data  -> PATH: repoint to your local globals.
*   - drop if year<=2002 ; drop if year>=2008   (analysis window 2003-2007).
*   - drop gryr*_2005   (2005 = omitted base year for grade x year dummies).
*   - replace math_lag/ela_lag = ...0005 if year>2005 (pre-Katrina lag cap).
*   - replace math_lagyear/ela_lagyear = min(...,2004) (lag capped at 2004).
*   - gen time = year - 2002   (trend origin = 2002).
*   - replace `var' = 0 if year >= 2006  (PARTIAL TREND: zero school trends post-Katrina).
*   - All `replace ...=0 if year<=2005` lines: PRE-TREATMENT = no evacuees.
*   - discipline05 defined off year==2005; decile graph block keyed to year==2006
*     (that block is commented out).
*
* NOTE: Documentation comments only — no executable code was modified.
*       The data-prep section closely mirrors quartile_analysis_revision_d.do.
*===============================================================================
***ADDS SCHOOL SPECIFIC LINEAR TIME TRENDS***




* 6.24.10 I prepped the TA (test administrator numbers) for 2006-2009...and merge in...test the bad apple model

* 4/22/10  I switched to using scaled scores, try lagged dependent variable on rhs..I've updated the lag to use data back to 2000

* run it with and without lagged dependent
* run it defining percent katrina at school*year and school*year*grade level


* for the lagged dependent variable (math_lag and ela_lag) , I start with the most recent lag.  I then insist that the lag be a pre-katrina score...so in 2007 I allow a 2006 score to be the lag

* for the quartiles of katrina kids performance I use the most recent test score 

* one remaining issue is how I classify non-evacuees into quartiles...I previously used 2000-2005 data which is a little wierd bc those years are also included in the regression

* now I predict math and ela scores and sort into quartiles off predicted values

clear
set mem 8g
set matsize 4000
capture log close


*cd "D:\School\Katrina\LA DOE\Revision"
*log using la_log2_quartiles, text replace

* PATH: repoint to your local globals (this cd sets the working dir for all
* subsequent relative use/merge/outreg2 paths below)
cd /work/i/imberman/imberman/la_data

* 6.14 try another run in which I use the true lag rather than capping at 2005
set more off


* ---- LOAD DATA ----
use la_prepped_revision.dta
* sample 5




* ---- GRADE/YEAR SAMPLE RESTRICTIONS ----
* limit the years and grades
* for now drop all the way up through 2004 to prove it works when we use 00-04 for sorting
drop if year<=2002   // YEAR HARDCODE: analysis window starts 2003
drop if year>=2008   // YEAR HARDCODE: analysis window ends 2007

drop if grade_num==12
drop if grade_num==11

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

* ---- PRE-KATRINA LAGGED-SCORE CONTROLS ----
gen math_lag2=math_lag
gen ela_lag2=ela_lag
replace math_lag=math0005 if year>2005   // YEAR HARDCODE: post-Katrina lag forced to pre-Katrina (0005) score
replace ela_lag=ela0005 if year>2005     // YEAR HARDCODE: post-Katrina lag forced to pre-Katrina (0005) score


* ---- BASELINE ACHIEVEMENT QUARTILES (own score for sorting students) ----
* get baseline score for sorting students (2004, falling back to 2003)
gen math0004=math2004
replace math0004=math2003 if math0004==. & math2003!=.
* replace math0004=math2002 if math0004==. & math2002!=.
* replace math0004=math2001 if math0004==. & math2001!=.
* replace math0004=math2000 if math0004==. & math2000!=.
* BASELINE ACHIEVEMENT QUARTILES: own pre-Katrina math/ELA quartiles
bysort grade_num year: quantiles math0004 , gen(math_0004QUART) nq(4) stable

gen ela0004=ela2004
replace ela0004=ela2003 if ela0004==. & ela2003!=.
* replace ela0004=ela2002 if ela0004==. & ela2002!=.
* replace ela0004=ela2001 if ela0004==. & ela2001!=.
* replace ela0004=ela2000 if ela0004==. & ela2000!=.
bysort grade_num year: quantiles ela0004 , gen(ela_0004QUART) nq(4) stable



* get predicted values to sort guys into high and low types
* areg mathSTD free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7, absorb(sitecode) cluster(sitecode)
* predict math_fitted


* areg elaSTD free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7, absorb(sitecode) cluster(sitecode)
* predict ela_fitted



* bysort grade_num: quantiles math_fitted if year==2006, gen(math_hat_QUARTa) nq(4) stable
* egen math_hat_QUART=max(math_hat_QUARTa), by(id)

* bysort grade_num: quantiles ela_fitted if year==2006, gen(ela_hat_QUARTa) nq(4) stable
* egen ela_hat_QUART=max(ela_hat_QUARTa), by(id)





* bysort grade_num year: quantiles math_lag , gen(math_lagQUART) nq(4) stable
* bysort grade_num year: quantiles ela_lag , gen(ela_lagQUART) nq(4) stable


* drop the data from the Spring of 08 in order to match Houston

* drop if year>=2008
* drop gr*2008


* make 2005 and all its interactions with each grade the ommitted category
drop gryr*_2005   // YEAR HARDCODE: 2005 = omitted base year for grade x year dummies


***********************************
* ---- MERGE IN THE DISCIPLINE DATA (PATH: relative to cd above) ----
***********************************
capture drop _m
sort id year

merge id year, using discipline_prepped_microdata

tab _m

drop if _m==2


***********************************
* ---- MERGE IN TEST ADMINISTRATOR DATA (classroom ids; PATH: relative to cd) ----
***********************************
capture drop _m
sort id year

merge id year, using tanumbers06-09_prepped2.dta

tab _m

drop if _m==2


summ mathSTD elaSTD

tab year



* ---- DEFINE CLASSROOM (school x year x test-administrator number) ----
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


* ---- EVACUEE (RITA) SHARE AT SCHOOL x YEAR ----
* define percent Rita
egen percent_ritaTIMESERIES2=mean(rita), by(district_code school_code year)
replace percent_ritaTIMESERIES2=0 if year<=2005   // YEAR HARDCODE: no evacuees pre-2005-06

***************************
* ---- REDEFINE PERCENT KATRINA (evacuee share, school x year and x grade) ----
****************************


** do it within school and grade and class
** include the Rita kids as katrina kids

capture drop percent_katrinaTIMESERIES2

replace katrina_sum=1 if rita==1

egen percent_katrinaTIMESERIES2=mean(katrina_sum), by(district_code school_code year)
replace percent_katrinaTIMESERIES2=0 if year<=2005   // YEAR HARDCODE: evacuee share = 0 pre-2005-06


egen percent_katrinaTIMESERIESG=mean(katrina_sum), by(district_code school_code year grade_num)
replace percent_katrinaTIMESERIESG=0 if year<=2005   // YEAR HARDCODE: evacuee share = 0 pre-2005-06




* gen white=(black==0 & asian==0 & hisp==0)

* gen grade_num=real(grade)



***************************
* define katrina peer averages of discplined vs not
****************************

* ---- "BAD APPLE" SHARE: evacuee peers disciplined pre-Katrina ----
gen discipline05a=discipline_any if year==2005   // YEAR HARDCODE: 2005 baseline discipline status
egen discipline05=max(discipline05a), by(id)

egen percent_katrinaDISCIPLINE2=mean(katrina_sum*discipline05), by(district_code school_code year)
replace percent_katrinaDISCIPLINE2=0 if year<=2005   // YEAR HARDCODE: no evacuees pre-2005-06


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



****************************************************
* ---- (DISABLED) achievement-distribution decile graph for Scott & Adriana ----
* NOTE: the entire block below is commented out (/* ... */) and does not run.
* It would compute 2004/2005 score percentiles per school and bucket 2006
* students into deciles to compare natives vs. evacuees. YEAR HARDCODEs inside
* (year==2004/2005 for percentiles, year==2006 for bucketing) are inert here.
***************************************************

* run a collapse command to get the 04 05 percentiles of math and ela scores
/*
collapse (p10) mathp10=mathSTD elap10=elaSTD  (p20) mathp20=mathSTD elap20=elaSTD  (p30) mathp30=mathSTD elap30=elaSTD  (p40) mathp40=mathSTD elap40=elaSTD  (p50) mathp50=mathSTD elap50=elaSTD  (p60) mathp60=mathSTD elap60=elaSTD  (p70) mathp70=mathSTD elap70=elaSTD  (p80) mathp80=mathSTD elap80=elaSTD  (p90) mathp90=mathSTD elap90=elaSTD   if year==2005 | year==2004, by(sitecode)

sort sitecode
save percentiles0405, replace
endsas;


* merge in test score percentiles for each school based on 04 05 data
drop _m

sort sitecode

merge sitecode using percentiles0405


* for each every student in 2006, ask what percentile of 2004/ 2005 distribution they would fall in

gen math_decile1=0 if mathSTD!=. & year==2006
gen math_decile2=0 if mathSTD!=. & year==2006
gen math_decile3=0 if mathSTD!=. & year==2006
gen math_decile4=0 if mathSTD!=. & year==2006
gen math_decile5=0 if mathSTD!=. & year==2006
gen math_decile6=0 if mathSTD!=. & year==2006
gen math_decile7=0 if mathSTD!=. & year==2006
gen math_decile8=0 if mathSTD!=. & year==2006
gen math_decile9=0 if mathSTD!=. & year==2006
gen math_decile10=0 if mathSTD!=. & year==2006


replace math_decile1=1 if year==2006 & mathSTD!=. & mathSTD<=mathp10
replace math_decile2=1 if year==2006 & mathSTD>mathp10 & mathSTD<=mathp20
replace math_decile3=1 if year==2006 & mathSTD>mathp20 & mathSTD<=mathp30
replace math_decile4=1 if year==2006 & mathSTD>mathp30 & mathSTD<=mathp40
replace math_decile5=1 if year==2006 & mathSTD>mathp40 & mathSTD<=mathp50
replace math_decile6=1 if year==2006 & mathSTD>mathp50 & mathSTD<=mathp60
replace math_decile7=1 if year==2006 & mathSTD>mathp60 & mathSTD<=mathp70
replace math_decile8=1 if year==2006 & mathSTD>mathp70 & mathSTD<=mathp80
replace math_decile9=1 if year==2006 & mathSTD>mathp80 & mathSTD<=mathp90
replace math_decile10=1 if year==2006 & mathSTD!=. & mathSTD>mathp90



gen ela_decile1=0 if elaSTD!=. & year==2006
gen ela_decile2=0 if elaSTD!=. & year==2006
gen ela_decile3=0 if elaSTD!=. & year==2006
gen ela_decile4=0 if elaSTD!=. & year==2006
gen ela_decile5=0 if elaSTD!=. & year==2006
gen ela_decile6=0 if elaSTD!=. & year==2006
gen ela_decile7=0 if elaSTD!=. & year==2006
gen ela_decile8=0 if elaSTD!=. & year==2006
gen ela_decile9=0 if elaSTD!=. & year==2006
gen ela_decile10=0 if elaSTD!=. & year==2006


replace ela_decile1=1 if year==2006 & elaSTD!=. & elaSTD<=elap10
replace ela_decile2=1 if year==2006 & elaSTD>elap10 & elaSTD<=elap20
replace ela_decile3=1 if year==2006 & elaSTD>elap20 & elaSTD<=elap30
replace ela_decile4=1 if year==2006 & elaSTD>elap30 & elaSTD<=elap40
replace ela_decile5=1 if year==2006 & elaSTD>elap40 & elaSTD<=elap50
replace ela_decile6=1 if year==2006 & elaSTD>elap50 & elaSTD<=elap60
replace ela_decile7=1 if year==2006 & elaSTD>elap60 & elaSTD<=elap70
replace ela_decile8=1 if year==2006 & elaSTD>elap70 & elaSTD<=elap80
replace ela_decile9=1 if year==2006 & elaSTD>elap80 & elaSTD<=elap90
replace ela_decile10=1 if year==2006 & elaSTD!=. & elaSTD>elap90


* now summ these decile dummies for native students versus katrina students in the relevant schools

summ math_decile* ela_decile* if katrina_sum!=1 & katrina_district2==0 & percent_katrina<.3


summ math_decile* ela_decile* if katrina_sum==1 & katrina_district2==0 & percent_katrina<.3

endsas;
*/

capture drop mathQD*
capture drop elaQD*

tab mathQUART, gen(mathQD)
tab elaQUART, gen(elaQD)





* ---- EVACUEE SHARE BY BASELINE QUARTILE — SCHOOL x YEAR (key RHS regressors) ----
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





* YEAR HARDCODE: school-level evacuee share by quartile = 0 pre-2005-06
replace Kfraction_mathQ1=0 if year<=2005
replace Kfraction_mathQ2=0 if year<=2005
replace Kfraction_mathQ3=0 if year<=2005
replace Kfraction_mathQ4=0 if year<=2005

replace Kfraction_elaQ1=0 if year<=2005
replace Kfraction_elaQ2=0 if year<=2005
replace Kfraction_elaQ3=0 if year<=2005
replace Kfraction_elaQ4=0 if year<=2005






* ---- EVACUEE SHARE BY BASELINE QUARTILE — SCHOOL x YEAR x GRADE LEVEL ----
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





* YEAR HARDCODE: grade-level evacuee share by quartile = 0 pre-2005-06
replace Kfraction_mathQ1G=0 if year<=2005
replace Kfraction_mathQ2G=0 if year<=2005
replace Kfraction_mathQ3G=0 if year<=2005
replace Kfraction_mathQ4G=0 if year<=2005

replace Kfraction_elaQ1G=0 if year<=2005
replace Kfraction_elaQ2G=0 if year<=2005
replace Kfraction_elaQ3G=0 if year<=2005
replace Kfraction_elaQ4G=0 if year<=2005



**************
* ---- LAG x YEARS-SINCE-LAG INTERACTIONS (year_gap dummies) ----
** try interacting lag with number of years between now and lag
**************
gen math_lagyear2=math_lagyear

* recall that lag is constrained to be 2004 or earlier
replace math_lagyear=min(math_lagyear, 2004)   // YEAR HARDCODE: cap lag year at 2004 (pre-Katrina)
replace math_lagyear=. if math_lagyear2==.

gen year_gap=year-math_lagyear
tab year_gap, gen(year_gapD)


gen ela_lagyear2=ela_lagyear

* recall that lag is constrained to be 2004 or earlier
replace ela_lagyear=min(ela_lagyear, 2004)   // YEAR HARDCODE: cap lag year at 2004 (pre-Katrina)
replace ela_lagyear=. if ela_lagyear2==.

gen year_gapE=year-ela_lagyear
tab year_gapE, gen(year_gapED)




gen math_lag_1=math_lag*year_gapD1
gen math_lag_2=math_lag*year_gapD2
gen math_lag_3=math_lag*year_gapD3
gen math_lag_4=math_lag*year_gapD4
gen math_lag_5=math_lag*year_gapD5
gen math_lag_6=math_lag*year_gapD6



gen ela_lag_1=ela_lag*year_gapED1
gen ela_lag_2=ela_lag*year_gapED2
gen ela_lag_3=ela_lag*year_gapED3
gen ela_lag_4=ela_lag*year_gapED4
gen ela_lag_5=ela_lag*year_gapED5
gen ela_lag_6=ela_lag*year_gapED6





*******************************
*******************************
*** what's the effect of number of katrina kids in my classrom
*** what's the effect of discplined katrina kids in my classroom
*******************************
*******************************

* ---- Clear prior outreg2 output files (PATH: relative to cd above) ----
cap rm elem_trends.txt
cap rm elem_trends.xls

cap rm midhigh_trends.txt
cap rm midhigh_trends.xls


*===============================================================================
* ESTIMATION BATTERY BEGINS (App Tables 23 & 24)
* Sample restriction (incumbent natives outside evac area, percent_katrina<.7)
* is applied inline via the `if` clauses below rather than a prior keep.
* lincom-style monotonicity/boutique tests are noted in comments but run via
* the repeated quartile regressions.
*===============================================================================

**************
** Overall Table ***
**************

*******************************
*******************************
*** Show that the pattern holds even before we split into quantiles of own ability
*******************************
*******************************
* ---- SCHOOL-SPECIFIC LINEAR TIME TRENDS (i.sitecode*year -> _I*) ----
gen time = year - 2002   // YEAR HARDCODE: trend origin = 2002 (first kept year)
xi i.sitecode*year       // generates school x year interaction terms (_Isit*) = school trends

* ---- "FULL TREND" PANEL, ALL STUDENTS (App 23/24): school trends over full window ----
reg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* _I* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num<=5  ,  cluster(sitecode)
outreg2 Kfraction_* using elem_trend.xls, excel dec(2) ctitle("Full Trend, Math, All")

reg mathSTD math_lag_* Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* _I* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num>5  ,  cluster(sitecode)
outreg2 Kfraction_* using midhigh_trend.xls, excel dec(2) ctitle("Full Trend, Math, All")

reg elaSTD Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* _I* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num<=5  ,  cluster(sitecode)
outreg2 Kfraction_* using elem_trend.xls, excel dec(2) ctitle("Full Trend, ELA, All")

reg elaSTD ela_lag_* Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* _I* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num>5  ,  cluster(sitecode)
outreg2 Kfraction_* using midhigh_trend.xls, excel dec(2) ctitle("Full Trend, ELA, All")




*******************************
*******************************
*** within each quartile of own past performance, ask how fraction katrina in each quartile matters
*******************************
*******************************
* ---- "FULL TREND" PANEL, BY OWN BASELINE QUARTILE (App 23/24) ----
* One regression per own-quartile (mathQD1..4 / elaQD1..4); the boutique &
* monotonicity tests are read off the four quartile coefficients across rows.


***
* after each regression, test for monotonicity, botiqueing
****

****Run it for elementary ****
reg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* _I* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num<=5 & mathQD1==1 ,  cluster(sitecode)
outreg2 Kfraction_* using elem_trend.xls, excel dec(2) ctitle("Full Trend, Math, Q1")

reg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* _I* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num<=5 & mathQD2==1 ,  cluster(sitecode)
outreg2 Kfraction_* using elem_trend.xls, excel dec(2) ctitle("Full Trend, Math, Q2")

reg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* _I* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num<=5 & mathQD3==1 ,  cluster(sitecode)
outreg2 Kfraction_* using elem_trend.xls, excel dec(2) ctitle("Full Trend, Math, Q3")

reg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* _I* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num<=5 & mathQD4==1 ,  cluster(sitecode)
outreg2 Kfraction_* using elem_trend.xls, excel dec(2) ctitle("Full Trend, Math, Q4")


* middle and high schools
reg mathSTD math_lag_* Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* _I* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num>5 & mathQD1==1 ,  cluster(sitecode)
outreg2 Kfraction_* using midhigh_trend.xls, excel dec(2) ctitle("Full Trend, Math, Q1")
* predict fitted_mathQ1G_MH if e(sample)


reg mathSTD math_lag_* Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* _I* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num>5 & mathQD2==1 ,  cluster(sitecode)
outreg2 Kfraction_* using midhigh_trend.xls, excel dec(2) ctitle("Full Trend, Math, Q2")
* predict fitted_mathQ2G_MH if e(sample)


reg mathSTD math_lag_* Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* _I* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num>5 & mathQD3==1 ,  cluster(sitecode)
outreg2 Kfraction_* using midhigh_trend.xls, excel dec(2) ctitle("Full Trend, Math, Q3")
* predict fitted_mathQ3G_MH if e(sample)

reg mathSTD math_lag_* Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* _I* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num>5 & mathQD4==1 ,  cluster(sitecode)
outreg2 Kfraction_* using midhigh_trend.xls, excel dec(2) ctitle("Full Trend, Math, Q4")
* predict fitted_mathQ4G_MH if e(sample)



* results for ELA elementary


reg elaSTD Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* _I* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num<=5 & elaQD1==1 ,  cluster(sitecode)
outreg2 Kfraction_* using elem_trend.xls, excel dec(2) ctitle("Full Trend, ELA, Q1")
* predict fitted_elaQ1G_elem if e(sample)


reg elaSTD Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* _I* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num<=5 & elaQD2==1 ,  cluster(sitecode)
outreg2 Kfraction_* using elem_trend.xls, excel dec(2) ctitle("Full Trend, ELA, Q2")
* predict fitted_elaQ2G_elem if e(sample)


reg elaSTD Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* _I* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num<=5 & elaQD3==1 ,  cluster(sitecode)
outreg2 Kfraction_* using elem_trend.xls, excel dec(2) ctitle("Full Trend, ELA, Q3")
* predict fitted_elaQ3G_elem if e(sample)

reg elaSTD Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* _I* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num<=5 & elaQD4==1 ,  cluster(sitecode)
outreg2 Kfraction_* using elem_trend.xls, excel dec(2) ctitle("Full Trend, ELA, Q4")
* predict fitted_elaQ4G_elem if e(sample)




* results for ELA middle and high


reg elaSTD ela_lag_* Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* _I* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num>5 & elaQD1==1 ,  cluster(sitecode)
outreg2 Kfraction_* using midhigh_trend.xls, excel dec(2) ctitle("Full Trend, ELA, Q1")
* predict fitted_elaQ1G_MH if e(sample)


reg elaSTD ela_lag_* Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* _I* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num>5 & elaQD2==1 ,  cluster(sitecode)
outreg2 Kfraction_* using midhigh_trend.xls, excel dec(2) ctitle("Full Trend, ELA, Q2")
* predict fitted_elaQ2G_MH if e(sample)


reg elaSTD ela_lag_* Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* _I* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num>5 & elaQD3==1 ,  cluster(sitecode)
outreg2 Kfraction_* using midhigh_trend.xls, excel dec(2) ctitle("Full Trend, ELA, Q3")
* predict fitted_elaQ3G_MH if e(sample)

reg elaSTD ela_lag_* Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* _I* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num>5 & elaQD4==1 ,  cluster(sitecode)
outreg2 Kfraction_* using midhigh_trend.xls, excel dec(2) ctitle("Full Trend, ELA, Q4")
* predict fitted_elaQ4G_MH if e(sample)


*===============================================================================
****PARTIAL TREND --> SET SCHOOL SPECIFIC TREND VARIABLES TO 0 AFTER KATRINA
* "PARTIAL TREND" PANEL (App 23/24): zero the school-specific trend terms in
* post-Katrina years so the trends are estimated off PRE-treatment data only,
* then re-run the full battery. This avoids the trends "absorbing" the treatment.
*===============================================================================

foreach var of varlist _IsitX* {
  replace `var' = 0 if year >= 2006   // YEAR HARDCODE: zero school trends in post-Katrina years (>=2006)
}

* ---- "PARTIAL TREND" PANEL, ALL STUDENTS ----
reg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* _I* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num<=5  ,  cluster(sitecode)
outreg2 Kfraction_* using elem_trend.xls, excel dec(2) ctitle("Partial Trend, Math, All")

reg mathSTD math_lag_* Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* _I* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num>5  ,  cluster(sitecode)
outreg2 Kfraction_* using midhigh_trend.xls, excel dec(2) ctitle("Partial Trend, Math, All")

reg elaSTD Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* _I* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num<=5  ,  cluster(sitecode)
outreg2 Kfraction_* using elem_trend.xls, excel dec(2) ctitle("Partial Trend, ELA, All")

reg elaSTD ela_lag_* Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* _I* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num>5  ,  cluster(sitecode)
outreg2 Kfraction_* using midhigh_trend.xls, excel dec(2) ctitle("Partial Trend, ELA, All")




*******************************
*******************************
*** within each quartile of own past performance, ask how fraction katrina in each quartile matters
*******************************
*******************************


***
* after each regression, test for monotonicity, botiqueing
****

* ---- "PARTIAL TREND" PANEL, BY OWN BASELINE QUARTILE ----
****Run it for elementary ****
reg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* _I* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num<=5 & mathQD1==1 ,  cluster(sitecode)
outreg2 Kfraction_* using elem_trend.xls, excel dec(2) ctitle("Partial Trend, Math, Q1")

reg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* _I* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num<=5 & mathQD2==1 ,  cluster(sitecode)
outreg2 Kfraction_* using elem_trend.xls, excel dec(2) ctitle("Partial Trend, Math, Q2")

reg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* _I* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num<=5 & mathQD3==1 ,  cluster(sitecode)
outreg2 Kfraction_* using elem_trend.xls, excel dec(2) ctitle("Partial Trend, Math, Q3")

reg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* _I* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num<=5 & mathQD4==1 ,  cluster(sitecode)
outreg2 Kfraction_* using elem_trend.xls, excel dec(2) ctitle("Partial Trend, Math, Q4")


* middle and high schools
reg mathSTD math_lag_* Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* _I* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num>5 & mathQD1==1 ,  cluster(sitecode)
outreg2 Kfraction_* using midhigh_trend.xls, excel dec(2) ctitle("Partial Trend, Math, Q1")
* predict fitted_mathQ1G_MH if e(sample)


reg mathSTD math_lag_* Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* _I* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num>5 & mathQD2==1 ,  cluster(sitecode)
outreg2 Kfraction_* using midhigh_trend.xls, excel dec(2) ctitle("Partial Trend, Math, Q2")
* predict fitted_mathQ2G_MH if e(sample)


reg mathSTD math_lag_* Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* _I* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num>5 & mathQD3==1 ,  cluster(sitecode)
outreg2 Kfraction_* using midhigh_trend.xls, excel dec(2) ctitle("Partial Trend, Math, Q3")
* predict fitted_mathQ3G_MH if e(sample)

reg mathSTD math_lag_* Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* _I* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num>5 & mathQD4==1 ,  cluster(sitecode)
outreg2 Kfraction_* using midhigh_trend.xls, excel dec(2) ctitle("Partial Trend, Math, Q4")
* predict fitted_mathQ4G_MH if e(sample)



* results for ELA elementary


reg elaSTD Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* _I* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num<=5 & elaQD1==1 ,  cluster(sitecode)
outreg2 Kfraction_* using elem_trend.xls, excel dec(2) ctitle("Partial Trend, ELA, Q1")
* predict fitted_elaQ1G_elem if e(sample)


reg elaSTD Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* _I* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num<=5 & elaQD2==1 ,  cluster(sitecode)
outreg2 Kfraction_* using elem_trend.xls, excel dec(2) ctitle("Partial Trend, ELA, Q2")
* predict fitted_elaQ2G_elem if e(sample)


reg elaSTD Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* _I* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num<=5 & elaQD3==1 ,  cluster(sitecode)
outreg2 Kfraction_* using elem_trend.xls, excel dec(2) ctitle("Partial Trend, ELA, Q3")
* predict fitted_elaQ3G_elem if e(sample)

reg elaSTD Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* _I* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num<=5 & elaQD4==1 ,  cluster(sitecode)
outreg2 Kfraction_* using elem_trend.xls, excel dec(2) ctitle("Partial Trend, ELA, Q4")
* predict fitted_elaQ4G_elem if e(sample)




* results for ELA middle and high


reg elaSTD ela_lag_* Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* _I* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num>5 & elaQD1==1 ,  cluster(sitecode)
outreg2 Kfraction_* using midhigh_trend.xls, excel dec(2) ctitle("Partial Trend, ELA, Q1")
* predict fitted_elaQ1G_MH if e(sample)


reg elaSTD ela_lag_* Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* _I* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num>5 & elaQD2==1 ,  cluster(sitecode)
outreg2 Kfraction_* using midhigh_trend.xls, excel dec(2) ctitle("Partial Trend, ELA, Q2")
* predict fitted_elaQ2G_MH if e(sample)


reg elaSTD ela_lag_* Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* _I* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num>5 & elaQD3==1 ,  cluster(sitecode)
outreg2 Kfraction_* using midhigh_trend.xls, excel dec(2) ctitle("Partial Trend, ELA, Q3")
* predict fitted_elaQ3G_MH if e(sample)

reg elaSTD ela_lag_* Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* _I* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num>5 & elaQD4==1 ,  cluster(sitecode)
outreg2 Kfraction_* using midhigh_trend.xls, excel dec(2) ctitle("Partial Trend, ELA, Q4")
* predict fitted_elaQ4G_MH if e(sample)



