*===============================================================================
* FILE:     discipline.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Data cleaning
* PRODUCES: Intermediate datasets discipline.dta and infracs.dta (the disciplinary
*           outcome inputs to the master Houston merge in merge_c.do)
*
* PURPOSE:  Assembles the raw yearly HISD disciplinary-action files (each with a
*           different schema and a different infraction/disposition code scheme)
*           into a consistent panel. For every school year it: loads the file,
*           classifies each incident into infraction TYPES (violate / substance /
*           crime / fighting) and PUNISHMENTS (out-/in-school suspension,
*           expulsion, AEP placement, continuations), saves an infraction-level
*           file, and collapses to one record per student with annual counts.
*           Finally appends all years into infracs.dta (incident level) and
*           discipline.dta (student-year counts).
*
* INPUTS:   dis9394, dis9495, dis9596, ... dis0607 (raw yearly discipline files)
* OUTPUTS:  infracs.dta (incident level), discipline.dta (student-year counts)
*
* KEY STEPS:
*   - Per-year blocks (1993..2006): rename raw fields, code infraction types &
*     punishments via foreach-numlist code maps, save infracsYYYY, collapse to
*     student-year counts saved as tempYYYY
*   - Code maps differ by era (1993-96 vs 1997-98 vs 1999+ schemes)
*   - Append infracs1993..2006 -> infracs.dta; append temp1993..2006 -> discipline.dta
*
* HARDCODED YEARS / PATHS TO UPDATE FOR A NEW-YEARS REPLICATION:
*   - cd "C:\D\...\Discipline\"                                       (PATH)
*   - save "C:\D\...\Discipline\infracs.dta" / discipline.dta         (PATH)
*   - Every per-year block hardcodes its source file (dis9394 .. dis0607) and the
*     gen year = YYYY / local i = YYYY stamp                          (YEAR HARDCODE)
*   - local i 2000 ; foreach year "0001" "0102"                       (YEAR HARDCODE)
*   - local i 2002 ; foreach year "0203" "0304" "0405" "0506" "0607"  (YEAR HARDCODE)
*   - forvalues year = 1993/2005 append loops (base file is 2006)     (YEAR HARDCODE)
*   - Infraction/disposition numlist code maps are era-specific; new years may use
*     a different code scheme and must be re-checked.
*
* NOTE: Documentation comments only — no executable code was modified.
*===============================================================================
*PUTS TOGETHER DISCIPLINARY ACTION FILES

clear
set mem 500m
set more off
cd "C:\D\Research\Charter\Houston\HISDdata\DataFiles\Discipline\"   // PATH: repoint to your local globals

*PUT FILES INTO APPENDABLE FORM

* ---- 1993 (dis9394): suspension-days schema; collapse to per-student counts ----
	*1993
	use dis9394, clear
	destring, replace

	gen anyinf = 1
	rename days_in_ susp_in_days
	rename days_out_of susp_out_days
	gen temp = expulsion == "X"
	drop expulsion
	rename temp expulsion
	drop bus* corp date_of campus

	drop if susp_out_days == 0 & susp_in_days == 0 & expulsion == 0. 

	gen susp_out = susp_out_days > 0 & susp_out_days != .
	gen susp_in = susp_in_days > 0 & susp_in_days != .
	sort id
	collapse (sum) susp_in susp_out expulsion anyinf, by (id)
	gen susp_tot = susp_in + susp_out
	sort id
	gen year = 1993       // YEAR HARDCODE: stamp 1993
	save temp1993, replace

* ---- 1994 (dis9495): suspension-days schema; also saves infracs1994 ----
	*1994
	use dis9495, clear
	destring, replace

	gen anyinf = 1
	rename days_of_in susp_in_days
	rename days_out_of susp_out_days
	drop referred
	gen temp = expulsion == "X"
	drop expulsion
	rename temp expulsion

	drop if susp_out_days == 0 & susp_in_days == 0 & expulsion == 0. 

	drop corp date_of*  campus
	gen susp_out = susp_out_days > 0 & susp_out_days != .
	gen susp_in = susp_in_days > 0 & susp_in_days != .
	sort id


	*SAVE INFRACTION LEVEL DATASET
	save infracs1994, replace

	collapse (sum) susp_in susp_out expulsion anyinf, by (id)

	gen susp_tot = susp_in + susp_out
	sort id
	gen year = 1994       // YEAR HARDCODE: stamp 1994
	save temp1994, replace

* ---- 1995 (dis9596): infraction-code scheme; types violate/substance/crime ----
*1995
use dis9596, clear
gen anyinf = 1
destring, replace
drop campus gender ethnicity date* rac
rename infraction_code infr_code
	
	*KEEP ONLY IF # DAYS > 0
	keep if number_of_days > 0

	*CORRECT SOME BAD IDS
	replace id = id + 8100000000 if id < 9000000000

	*IDENTIFY TYPE OF INFRACTION
	gen violate = 0
	foreach code of numlist 1/16 26/38 49/51 60 {
		replace violate = 1 if infr_code == `code'
	}
	label variable violate "general violation of student code"
	
	gen substance = (infr_code >= 17 & infr_code <= 25)
	label variable substance "use or sale of illegal substances inc alcohol"


	gen crime = 0
	foreach code of numlist 39/48 52/59 {
		replace crime = 1 if infr_code == `code'
	}
	label variable crime "behavior that could be tried as a non-drug crime"

	*SAVE INFRACTION LEVEL DATASET
	save infracs1995, replace

	*COLLAPSE TO ONE RECORD PER STUDENT
	collapse (sum) anyinf violate substance crime, by (id)
	sort id
	sum
	gen year = 1995       // YEAR HARDCODE: stamp 1995
	save temp1995, replace

* ---- 1996 (dis9697): same infraction-code scheme as 1995 ----
*1996
use dis9697, clear
gen anyinf = 1
destring, replace
drop sch gender ethnic date* dmts
rename infraction infr_code

	*KEEP ONLY IF # DAYS > 0
	destring no_days, replace
	keep if no_days > 0 & no_days != .
	
	*IDENTIFY TYPE OF INFRACTION
	gen violate = 0
	foreach code of numlist 1/16 26/38 49/51 60 {
		replace violate = 1 if infr_code == `code'
	}
	label variable violate "general violation of student code"
	
	gen substance = (infr_code >= 17 & infr_code <= 25)
	label variable substance "use or sale of illegal substances inc alcohol"
		
	gen crime = 0
	foreach code of numlist 39/48 52/59 {
		replace crime = 1 if infr_code == `code'
	}
	label variable crime "behavior that could be tried as a non-drug crime"
	sort id

	*SAVE INFRACTION LEVEL DATASET
	save infracs1996, replace

	*COLLAPSE TO ONE RECORD PER STUDENT
	collapse (sum) anyinf violate substance crime, by (id)
	sort id
	sum
	gen year = 1996       // YEAR HARDCODE: stamp 1996
	save temp1996, replace

* ---- 1997 (dis9798): new code scheme; adds disposition codes & punishments ----
*1997
use dis9798, clear
gen anyinf = 1
destring, replace
drop campus 
rename disp_action_code dis_code
rename discp_action_rea infr_code
		
	*IDENTIFY TYPE OF INFRACTION
	gen violate = 0
	foreach code of numlist 1 9 10 20 21 23 24 99 {
		replace violate = 1 if infr_code == `code'
	}
	label variable violate "general violation of student code & disruptive behavior"
	
	gen substance = 0
	foreach code of numlist 4/6 {
		replace substance = 1 if infr_code == `code'
	}
	label variable substance "use or sale of illegal substances inc alcohol"
		
	gen crime  = 0
	foreach code of numlist 2 3 7 8 11/19 22 {
		replace crime = 1 if infr_code == `code'
	}
	label variable crime "behavior that could be tried as a non-drug crime"
	sort id

	*IDENTIFY PUNISHMMENT
	
		*EXPULSION OR COURT ORDERED PLACEMENT IN JUVENILE JUSTICE
		gen expulsion = (dis_code >= 1 & dis_code <= 4)  | dis_code == 9

		*OUT-OF-SCHOOL SUSPENSION
		gen susp_out = dis_code == 5
		
		*IN-SCHOOL SUSPENSION
		gen susp_in = dis_code == 6 

		*PLACEMENT IN AEP W/O EXPULSION
		gen aep = dis_code == 7 | dis_code == 8

	*SAVE INFRACTION LEVEL DATASET
	save infracs1997, replace

	*COLLAPSE TO ONE RECORD PER STUDENT
	collapse (sum) anyinf violate substance crime susp* exp* aep* , by (id)

	sort id
	gen year = 1997       // YEAR HARDCODE: stamp 1997
	sum
	save temp1997, replace

* ---- 1998 (dis9899): same scheme as 1997 ----
*1998
use dis9899, clear
gen anyinf = 1
destring, replace
drop campus 
rename disc_action_code dis_code
rename disc_action_rea infr_code
rename actual_length length_


	*IDENTIFY TYPE OF INFRACTION
	gen violate = 0
	foreach code of numlist 1 9 10 20 21 23 24 99 {
		replace violate = 1 if infr_code == `code'
	}
	label variable violate "general violation of student code & disruptive behavior"
	
	gen substance = 0
	foreach code of numlist 4/6 {
		replace substance = 1 if infr_code == `code'
	}
	label variable substance "use or sale of illegal substances inc alcohol"
		
	gen crime  = 0
	foreach code of numlist 2 3 7 8 11/19 22 {
		replace crime = 1 if infr_code == `code'
	}
	label variable crime "behavior that could be tried as a non-drug crime"
	sort id

	*IDENTIFY PUNISHMMENT
	
		*EXPULSION OR COURT ORDERED PLACEMENT IN JUVENILE JUSTICE
		gen expulsion = (dis_code >= 1 & dis_code <= 4) | dis_code == 9

		*OUT-OF-SCHOOL SUSPENSION
		gen susp_out = dis_code == 5
		
		*IN-SCHOOL SUSPENSION
		gen susp_in = dis_code == 6 

		*PLACEMENT IN AEP W/O EXPULSION
		gen aep = dis_code == 7 | dis_code == 8

	*SAVE INFRACTION LEVEL DATASET
	save infracs1998, replace

	*COLLAPSE TO ONE RECORD PER STUDENT
	collapse (sum) anyinf violate substance crime susp* exp* aep* , by (id)

	sort id
	gen year = 1998       // YEAR HARDCODE: stamp 1998
	sum
	save temp1998, replace


* ---- 1999 (dis9900): expanded disposition/infraction code scheme; adds other/cont ----
*1999
use dis9900, clear
gen anyinf = 1
destring, replace
drop campus 
rename disciplinaryactioncode dis_code
rename disciplinaryactionreasoncode infr_code
rename actuallength length_


	*CORRECT TYPO
	replace length_ = 186 if length == 986

	*IDENTIFY PUNISHMMENT
	
		*EXPULSION OR COURT ORDERED PLACEMENT IN JUVENILE JUSTICE
		gen expulsion = 0
		foreach code of numlist 1/4 9 11 13 15 50/53 56 60/61 {
			replace expulsion = 1 if dis_code == `code'
		}

		*OUT-OF-SCHOOL SUSPENSION
		gen susp_out = dis_code == 5 | dis_code == 25
		
		*IN-SCHOOL SUSPENSION
		gen susp_in = dis_code == 6 | dis_code == 26

		*PLACEMENT IN AEP W/O EXPULSION
		gen aep = 0
		foreach code of numlist 7 8 14 54 55 {
			replace aep = 1 if dis_code == `code'
		}

		*OTHER
		gen other =  dis_code == 16 | dis_code == 17 | dis_code == 99

		*CONTINUATION OF PREVIOUS YEAR'S EXPULSION
		gen contexp = dis_code == 11 | dis_code == 12 | dis_code == 58 |dis_code == 59

		*CONTINUATION OF PREVIOUS YEAR'S AEP PLACEMENT
		gen contaep = dis_code == 10 | dis_code == 57

	*IDENTIFY TYPE OF INFRACTION
	gen violate = 0
	foreach code of numlist 1 9 10 20 21 23 33 41/45 99 {
		replace violate = 1 if infr_code == `code'
	}
	label variable violate "general violation of student code & disruptive behavior"
	
	gen substance = 0
	foreach code of numlist 4/6 {
		replace substance = 1 if infr_code == `code'
	}
	label variable substance "use or sale of illegal substances inc alcohol but not tobacco"
		
	gen crime  = 0
	foreach code of numlist 2 7 8 11/19 22 26/32 34/37 46/49{
		replace crime = 1 if infr_code == `code'
	}
	label variable crime "behavior that could be tried as a non-drug crime"
	sort id


	*SAVE INFRACTION LEVEL DATASET
	save infracs1999, replace

	*COLLAPSE TO ONE RECORD PER STUDENT
	collapse (sum) anyinf violate substance crime susp* exp* aep* cont*, by (id)

	sort id
	gen year = 1999       // YEAR HARDCODE: stamp 1999
	sum
	save temp1999, replace

* ---- 2000-2001 (dis0001, dis0102): looped; same scheme as 1999 ----
*2000 - 2001
* YEAR HARDCODE: local i seeds output year (2000); foreach lists raw file suffixes
local i  2000
foreach year in "0001" "0102" {
	use dis`year', clear
	gen anyinf = 1
	destring, replace
	drop campus 
	rename disciplinaryactioncode dis_code
	rename disciplinaryactionreasoncode infr_code
	rename actuallength length_


	*IDENTIFY PUNISHMMENT
	
		*EXPULSION OR COURT ORDERED PLACEMENT IN JUVENILE JUSTICE
		gen expulsion = 0
		foreach code of numlist 1/4 9 11 13 15 50/53 56 60/61 {
			replace expulsion = 1 if dis_code == `code'
		}

		*OUT-OF-SCHOOL SUSPENSION
		gen susp_out = dis_code == 5 | dis_code == 25
		
		*IN-SCHOOL SUSPENSION
		gen susp_in = dis_code == 6 | dis_code == 26

		*PLACEMENT IN AEP W/O EXPULSION
		gen aep = 0
		foreach code of numlist 7 8 14 54 55 {
			replace aep = 1 if dis_code == `code'
		}

		*OTHER
		gen other =  dis_code == 16 | dis_code == 17 | dis_code == 99

		*CONTINUATION OF PREVIOUS YEAR'S EXPULSION
		gen contexp = dis_code == 11 | dis_code == 12 | dis_code == 58 |dis_code == 59

		*CONTINUATION OF PREVIOUS YEAR'S AEP PLACEMENT
		gen contaep = dis_code == 10 | dis_code == 57

	*IDENTIFY TYPE OF INFRACTION
	gen violate = 0
	foreach code of numlist 1 9 10 20 21 23 33 41/45 99 {
		replace violate = 1 if infr_code == `code'
	}
	label variable violate "general violation of student code & disruptive behavior"

	gen substance = 0
	foreach code of numlist 4/6 {
		replace substance = 1 if infr_code == `code'
	}
	label variable substance "use or sale of illegal substances inc alcohol but not tobacco"
		
	gen crime  = 0
	foreach code of numlist 2 7 8 11/19 22 26/32 34/37 46/49 50{
		replace crime = 1 if infr_code == `code'
	}
	label variable crime "behavior that could be tried as a non-drug crime"
	sort id

	*SAVE INFRACTION LEVEL DATASET
	save infracs`i', replace


	*COLLAPSE TO ONE RECORD PER STUDENT
	collapse (sum) anyinf violate substance crime susp* exp* aep* cont*, by (id)

	sort id
	gen year = `i'
	sum
	save temp`i', replace
	local i = `i' + 1
}

* ---- 2002-2006 (dis0203..dis0607): looped; same scheme + adds fighting flag ----
*2002 - 2006
* YEAR HARDCODE: local i seeds output year (2002); foreach lists raw file suffixes
local i  2002
foreach year in  "0203" "0304" "0405" "0506" "0607" {
	use dis`year', clear
	gen anyinf = 1
	destring, replace
	drop campus*
	rename disciplinaryactioncode dis_code
	rename disciplinaryactionreasoncode infr_code
	rename actuallength length_


	*IDENTIFY PUNISHMMENT
	
		*EXPULSION OR COURT ORDERED PLACEMENT IN JUVENILE JUSTICE
		gen expulsion = 0
		foreach code of numlist 1/4 9 11 13 15 50/53 56 60/61 {
			replace expulsion = 1 if dis_code == `code'
		}

		*OUT-OF-SCHOOL SUSPENSION
		gen susp_out = dis_code == 5 | dis_code == 25
		
		*IN-SCHOOL SUSPENSION
		gen susp_in = dis_code == 6 | dis_code == 26

		*PLACEMENT IN AEP W/O EXPULSION
		gen aep = 0
		foreach code of numlist 7 8 14 54 55 {
			replace aep = 1 if dis_code == `code'
		}

		*OTHER
		gen other =  dis_code == 16 | dis_code == 17 | dis_code == 99

		*CONTINUATION OF PREVIOUS YEAR'S EXPULSION
		gen contexp = dis_code == 11 | dis_code == 12 | dis_code == 58 |dis_code == 59

		*CONTINUATION OF PREVIOUS YEAR'S AEP PLACEMENT
		gen contaep = dis_code == 10 | dis_code == 57

	*IDENTIFY TYPE OF INFRACTION
	gen violate = 0
	foreach code of numlist 1 9 10 20 21 23 33 41/45 99 {
		replace violate = 1 if infr_code == `code'
	}
	label variable violate "general violation of student code & disruptive behavior"

	gen fighting = 0
	replace fighting = 1 if infr_code == 41
	label variable fighting "student involved in a fight"

	gen substance = 0
	foreach code of numlist 4/6 {
		replace substance = 1 if infr_code == `code'
	}
	label variable substance "use or sale of illegal substances inc alcohol but not tobacco"
		
	gen crime  = 0
	foreach code of numlist 2 7 8 11/19 22 26/32 34/37 46/49 50{
		replace crime = 1 if infr_code == `code'
	}
	label variable crime "behavior that could be tried as a non-drug crime"
	sort id

	*SAVE INFRACTION LEVEL DATASET
	save infracs`i', replace

	*COLLAPSE TO ONE RECORD PER STUDENT
	collapse (sum) anyinf violate substance crime susp* exp* aep* cont* fighting, by (id)

	sort id
	gen year = `i'
	sum
	save temp`i', replace
	local i = `i' + 1
}

* ---- Append all incident-level files -> infracs.dta ----
*APPEND REVISED INFRACTION LEVEL FILES
	use infracs2006, clear            // YEAR HARDCODE: base = 2006 incident file
	gen year = 2006                   // YEAR HARDCODE: stamp 2006
	forvalues year = 1993/2005 {      // YEAR HARDCODE: append 1993-2005 incident files
		append using infracs`year'.dta
		replace year = `year' if year == .
	}
	des
	sort id year
	label variable expulsion "expulsion or court ordered placement in JJAEP"
	label variable contexp "continuation of expulsion order from previous year"
	label variable aep "placement in AEP program w/o expulsion"
	label variable contaep "continuation of AEP placement from previous year"
	save "C:\D\Research\Charter\Houston\HISDdata\DataFiles\Discipline\infracs.dta", replace   // PATH: repoint to your local globals


* ---- Append all student-year count files -> discipline.dta (input to merge_c.do) ----
*APPEND TEMPORARY FILES
	use temp2006, clear               // YEAR HARDCODE: base = 2006 student-year file
	forvalues year = 1993/2005 {      // YEAR HARDCODE: append 1993-2005 student-year files
		append using temp`year'.dta
	}
	des
	tab year
	sort id year

	*LABEL VARIABLES
	label variable expulsion "expulsion or court ordered placement in JJAEP"
	label variable contexp "continuation of expulsion order from previous year"
	label variable aep "placement in AEP program w/o expulsion"
	label variable contaep "continuation of AEP placement from previous year"

	save "C:\D\Research\Charter\Houston\HISDdata\DataFiles\Discipline\discipline.dta", replace   // PATH: repoint to your local globals

