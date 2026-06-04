*===============================================================================
* FILE:     analyze_school_level2_quartiles_b.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Analysis (Louisiana) -- school-level resources / class size
* PRODUCES: Appendix Table 44 (effect of evacuee share in school on class sizes,
*           split by the evacuees' average math & reading achievement levels).
*
* PURPOSE:  Takes the merged LOUISIANA school-level dataset and regresses
*           school-level resource / class-size / attendance / suspension /
*           dropout outcomes on the evacuee-share-by-achievement-quartile
*           measures (Kfraction_Q1..Q4, averaged across math and ELA). Tests
*           whether higher- vs. lower-achieving evacuees differentially affect
*           class sizes and other school resources -- the resource-dilution
*           mechanism check for Louisiana.
*
* INPUTS:   merged_school_level_data.dta ; school_level_means.dta (sps/)
* OUTPUTS:  la_school_level.log ; regression / outreg output.
*
* KEY STEPS:
*   - Merge merged_school_level_data with school_level_means; keep matched.
*   - Recode missing class-size percentages to 0; rescale percentages to shares.
*   - Average math & ELA evacuee-quartile shares (rmean) into Kfraction_Q1..Q4.
*   - Run year-FE regressions of each school resource on the quartile shares.
*
* HARDCODED YEARS / PATHS TO UPDATE FOR A NEW-YEARS REPLICATION:
*   - cd c:/katrina and C:\katrina\sps\school_level_means  -> repoint to $work.
*   - xi i.year expands automatically with the data (check the omitted base year).
*
* NOTE: Documentation comments only -- no executable code was modified.
*===============================================================================

* this takes the merged school level data and runs a few regressions
clear
set mem 750m
capture log close
cd c:/katrina

log using la_school_level.log, text replace


cd "C:\katrina"
set more off




use merged_school_level_data, clear

*MERGE WITH SCHOOL LEVEL EXTRACTION FROM LA_WORKING_DATA3 TO MAKE SAMPLE RESTRICTIONS
drop _merge
sort sitecode year
merge sitecode year using C:\katrina\sps\school_level_means
keep if _merge == 3


*MISSING FOR PERCENT OF CLASSES APPEARS TO BE 0
foreach var of varlist percent_of_classes* {
  replace `var' = 0 if `var' == .
}


replace percent_of_classes1_20=percent_of_classes1_20/100
replace percent_of_classes21_26=percent_of_classes21_26/100
gen percent_of_classes27p=(percent_of_classes27_33 + percent_of_classes34p)/100

replace percent_of_student_attendance= percent_of_student_attendance /100


replace per_students_suspended_inschool= per_students_suspended_inschool/100

replace percent_of_dropouts9_12= percent_of_dropouts9_12/100


gen district_num=int(sitecode/1000)

xi i.year

summ percent_of_classes1_20 percent_of_classes21_26 per_students_suspended_inschool percent_of_dropouts9_12 percent_of_student_attendance

*GENERATE AVERAGE OF MATH & ELA KFRACTION SHARES
egen Kfraction_Q1 = rmean(Kfraction_mathQ1 Kfraction_elaQ1)
egen Kfraction_Q2 = rmean(Kfraction_mathQ2 Kfraction_elaQ2)
egen Kfraction_Q3 = rmean(Kfraction_mathQ3 Kfraction_elaQ3)
egen Kfraction_Q4 = rmean(Kfraction_mathQ4 Kfraction_elaQ4)



********************************************
* class size: percent classes 20 and under
********************************************
* run for just elementary
areg percent_of_classes1_20 Kfraction_Q1-Kfraction_Q4 _I* free_lunchA male black hisp asian gryr* if category_code=="001", absorb(sitecode) cluster(sitecode)

* run for just middle+high
areg percent_of_classes1_20 Kfraction_Q1-Kfraction_Q4 _I* free_lunchA male black hisp asian gryr* if (category_code=="002" | category_code=="003"), absorb(sitecode) cluster(sitecode)



********************************************
* class size: percent classes 21-26
********************************************
* run for just elementary
areg percent_of_classes21_26 Kfraction_Q1-Kfraction_Q4 _I* free_lunchA male black hisp asian gryr* if category_code=="001", absorb(sitecode) cluster(sitecode)

* run for just middle+high
areg percent_of_classes21_26 Kfraction_Q1-Kfraction_Q4 _I* free_lunchA male black hisp asian gryr* if (category_code=="002" | category_code=="003"),  absorb(sitecode) cluster(sitecode)


********************************************
* class size: percent classes 27p
********************************************
* run for just elementary
areg percent_of_classes27p Kfraction_Q1-Kfraction_Q4 _I* free_lunchA male black hisp asian gryr* if category_code=="001", absorb(sitecode) cluster(sitecode)

* run for just middle+high
areg percent_of_classes27p Kfraction_Q1-Kfraction_Q4 _I* free_lunchA male black hisp asian gryr* if (category_code=="002" | category_code=="003"),   absorb(sitecode) cluster(sitecode)




log close





/*


********************************************
* discipline: percent students suspended in school
********************************************
areg  per_students_suspended_inschool percent_katrinaTIMESERIES2 yeardum4-yeardum6 , absorb(sitecode) cluster(sitecode)


areg  per_students_suspended_inschool percent_katrinaTIMESERIES2 yeardum4-yeardum6 if percent_katrinaTIMESERIES2<.70, absorb(sitecode) cluster(sitecode)


areg  per_students_suspended_inschool percent_katrinaTIMESERIES2 yeardum4-yeardum6 if percent_katrinaTIMESERIES2<.70 & new_orleans_msa==0, absorb(sitecode) cluster(sitecode)

* run for just elementary
areg per_students_suspended_inschool percent_katrinaTIMESERIES2 yeardum4-yeardum6 if percent_katrinaTIMESERIES2<.70 & new_orleans_msa==0 & category_code=="001", absorb(sitecode) cluster(sitecode)

* run for just middle+high
areg per_students_suspended_inschool percent_katrinaTIMESERIES2 yeardum4-yeardum6 if percent_katrinaTIMESERIES2<.70 & new_orleans_msa==0 & (category_code=="003" | category_code=="002") , absorb(sitecode) cluster(sitecode)








********************************************
* dropouts: percent students dropping out during grades 9-12
********************************************

areg percent_of_dropouts9_12 percent_katrinaTIMESERIES2 yeardum4-yeardum6 , absorb(sitecode) cluster(sitecode)


areg percent_of_dropouts9_12 percent_katrinaTIMESERIES2 yeardum4-yeardum6 if percent_katrinaTIMESERIES2<.70, absorb(sitecode) cluster(sitecode)


areg percent_of_dropouts9_12 percent_katrinaTIMESERIES2 yeardum4-yeardum6 if percent_katrinaTIMESERIES2<.70 & new_orleans_msa==0, absorb(sitecode) cluster(sitecode)





********************************************
* attendance: percent students in attendance
********************************************

areg percent_of_student_attendance percent_katrinaTIMESERIES2 yeardum4-yeardum6 , absorb(sitecode) cluster(sitecode)


areg percent_of_student_attendance percent_katrinaTIMESERIES2 yeardum4-yeardum6 if percent_katrinaTIMESERIES2<.70, absorb(sitecode) cluster(sitecode)


areg percent_of_student_attendance percent_katrinaTIMESERIES2 yeardum4-yeardum6 if percent_katrinaTIMESERIES2<.70 & new_orleans_msa==0, absorb(sitecode) cluster(sitecode)


* run for just elementary
areg percent_of_student_attendance percent_katrinaTIMESERIES2 yeardum4-yeardum6 if percent_katrinaTIMESERIES2<.70 & new_orleans_msa==0 & category_code=="001", absorb(sitecode) cluster(sitecode)

* run for just middle+high
areg percent_of_student_attendance percent_katrinaTIMESERIES2 yeardum4-yeardum6 if percent_katrinaTIMESERIES2<.70 & new_orleans_msa==0 & (category_code=="003" | category_code=="002") , absorb(sitecode) cluster(sitecode)



