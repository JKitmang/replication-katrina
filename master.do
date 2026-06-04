*===============================================================================
* MASTER.DO
* PROJECT : "Katrina's Children: Evidence on the Structure of Peer Effects
*            from Hurricane Evacuees"
*            Scott A. Imberman, Adriana D. Kugler & Bruce I. Sacerdote
*            NBER WP 15291 ; American Economic Review
*
* PURPOSE : Single entry point that (1) defines all file paths in ONE place,
*           (2) documents the canonical order in which the original .do files
*           must run, and (3) lets you reproduce the full analysis by un-
*           commenting the `do` lines once the raw data and paths are in place.
*
* AUTHOR OF THIS FILE : Replication documentation pass (added for review /
*           re-use with new years of data). The original analysis .do files
*           were written by the authors; this master only orchestrates them.
*
* IMPORTANT - READ BEFORE RUNNING -------------------------------------------
*   The original .do files were written on the authors' own servers and contain
*   HARDCODED absolute paths, e.g.
*       /work/i/imberman/imberman/...           (Linux analysis server)
*       /home/s/simberman/work/hisd/katrina/... (Linux cleaning server)
*       C:\D\Research\Charter\Houston\...        (Windows cleaning machine)
*   They also `use`/`save` intermediate .dta files by bare name (relying on the
*   current working directory). Stata does NOT expand global macros that are
*   already baked into those files, so this master CANNOT silently redirect
*   them. To actually run end-to-end you must FIRST repoint the paths. Two ways:
*       (a) Recommended: do a project-wide find/replace of each hardcoded root
*           with the matching global defined below (see README, section
*           "Re-running with new years", step 2), OR
*       (b) Create folders on your machine that mirror the original absolute
*           paths and drop the data there.
*   Until that is done, treat the `do` lines below as the authoritative RUN
*   ORDER and run the files one at a time interactively.
* ---------------------------------------------------------------------------
*
* DATA ACCESS : The micro-data are proprietary (Houston ISD and the Louisiana
*           Dept. of Education). They are NOT included. See README for the
*           request procedure. This master assumes the raw extracts and the
*           authors' intermediate .dta files live under $raw / the cleaning dirs.
*===============================================================================

clear all
set more off
set varabbrev off       // safer: do not let abbreviations resolve unexpectedly
version 12              // the code was developed under Stata 11/12 syntax

*-------------------------------------------------------------------------------
* 0. CONFIGURATION -- EDIT THESE FOUR LINES, THEN (optionally) the dofiles
*-------------------------------------------------------------------------------
* Point $root at the folder that contains this master.do (the package root).
global root     "/Users/jostin.kitmang/Downloads/Imberman Replication"

global prog     "$root/programs"          // the .do files
global raw      "$root/data/raw"          // raw HISD + LA extracts (you provide)
global work     "$root/data/work"         // intermediate + final .dta files
global out      "$root/output"            // logs, tables, figures

cap mkdir "$root/data"
cap mkdir "$work"
cap mkdir "$out"

* Convenience: the original code's two analysis roots map onto $work, e.g.
*   /work/i/imberman/imberman/        ->  $work
*   /work/i/imberman/imberman/la_data ->  $work/la_data
* and the cleaning roots map onto $raw. Keep this mapping in mind when you
* repoint paths inside the individual .do files.

* ---- Required user-written (SSC) commands -- install once, then comment out --
* ssc install outreg2
* ssc install quantiles      // sorts obs into quantile groups (builds quartiles)
* ssc install renames        // batch rename used in taks_append
* (areg, ivreg, ivreg2, xtreg, xi, test, lincom are official Stata.)


*===============================================================================
* PART A. LOUISIANA -- DATA CLEANING & DATASET CONSTRUCTION
*   Inputs : LA_leap00_09.dta + la_prepped_revisionFULL_SAMPLE.dta (LDOE micro)
*   Output : alternative_standardization.dta, la_means.dta, school-level means
*-------------------------------------------------------------------------------
* do "$prog/alt_scale.do"            // clean raw LA, keep achievement SCALE scores
* do "$prog/alt_standardize.do"      // standardize scale scores within grade x year
* do "$prog/alt_standardize_2.do"    // standardize using ONLY non-evacuees
* do "$prog/school_level_means.do"   // collapse to school-level means (placebo/trend inputs)


*===============================================================================
* PART B. HOUSTON (HISD) -- DATA CLEANING
*   Each file ingests one raw domain and saves a tidy student-year .dta.
*   RUN ORDER MATTERS: merge_c.do consumes the outputs of the four files above it.
*-------------------------------------------------------------------------------
* do "$prog/attendence.do"           // -> attend_zip_katrina.dta (enrollment, attendance, evacuee flag)
* do "$prog/demographics_clean.do"   // -> demog_new.dta (race, gender, lunch, dob, programs)
* do "$prog/taks_append.do"          // -> taks.dta (TAKS test scores, long->wide by subject)
*   (the Stanford/Aprenda/TAAS/discipline/student-teacher extracts are built the
*    same way; discipline.do builds discipline.dta)
* do "$prog/discipline.do"           // -> discipline.dta (infraction counts)
*
* do "$prog/merge_c.do"              // *** MASTER MERGE ***  -> hisd_data.dta,
*                                    //   katrina_data_with_evacs.dta, katrina_data.dta,
*                                    //   maxgrade.dta. Builds evacuee shares (campus/
*                                    //   grade/class), the Sept-13-2005 INSTRUMENT,
*                                    //   statewide-standardized TAKS scores, and the
*                                    //   pre-Katrina achievement quartiles.


*===============================================================================
* PART C. HOUSTON -- ANALYSIS-DATASET CONSTRUCTION (depends on merge_c outputs)
*-------------------------------------------------------------------------------
* do "$prog/quartile_data.do"        // -> pre_katrina_quartiles.dta (incumbent quartiles)
* do "$prog/quintile_data.do"        // -> quintile version (App Table 6)
* do "$prog/placebo_quartile_data.do"// -> quartiles for the placebo/falsification test


*===============================================================================
* PART D. ANALYSIS -- BY PAPER TABLE
*   Re-run any single table by un-commenting its line. Files may write to the
*   log and/or to $out via outreg2; see each file's header for specifics.
*   (LA = Louisiana sample ; HOU = Houston/HISD sample.)
*-------------------------------------------------------------------------------

* ---- Table 1  : Descriptive stats, evacuees vs. natives -----------------------
* do "$prog/summary_stats_la.do"             // LA panel
* do "$prog/sumstats_houston.do"             // HOU panel
* do "$prog/sumstats_b.do"                   // HOU (school-weighted; also App Table 2)

* ---- Table 2  : Conditional evacuee-native gaps -------------------------------
* do "$prog/analysis_revision_linear.do"     // LA (also Table 5, App 12-13)
* do "$prog/katrina_nonkatrina.do"           // HOU

* ---- Table 3  : DiD of evacuee share on native test scores (HOU) --------------
* do "$prog/katrina_by_quartiles_va_grade_statestd.do"        // OLS reduced form (also Table 10)
* do "$prog/katrina_iv_gender_ethnicity_noshelter_grade.do"   // 2SLS (also Table 10, App 40)
* do "$prog/katrina_placebotest_grade.do"                     // placebo column

* ---- Table 4  : Nonlinear (above/below median) evacuee x quartile (HOU) -------
* do "$prog/katrina_by_quartiles_lim_test_fullint_math.do"    // math (also App 9-10)
* do "$prog/katrina_by_quartiles_lim_test_fullint_read.do"    // reading (also App 9-10)
* do "$prog/katrina_by_quartiles_pre_katrina_ols.do"          // pre-Katrina OLS rows

* ---- Table 5  : Nonlinear 4x4 quartile matrix (LA) ----------------------------
* do "$prog/quartile_analysis_revision_d.do"  // *** LA WORKHORSE *** Tables 5,7 and App
*                                             //   15-19, 21-22, 27-28, 30, 32-37, 39, 43
* (analysis_revision_linear.do also feeds Table 5)

* ---- Table 6  : Epple-Romano linear-in-means (LA/HOU) -------------------------
* do "$prog/epple_romano_f_math_grade_fullintb.do"            // math (also App 14)
* do "$prog/epple_romano_f_ela_grade_fullintb.do"             // ELA  (also App 14)

* ---- Table 7  : Bad-apple test (evacuee share x evacuee infractions) ----------
* (produced by quartile_analysis_revision_d.do -- run above)

* ---- Table 8  : Peer-structure model tests, no Bonferroni ---------------------
* do "$prog/quartile_analysis_revision_full_b_tests_nobon.do" // (also App 20)

* ---- Table 9  : Class-size effects --------------------------------------------
* do "$prog/school_level_placebo_b.do"        // school-level placebo (also App 25-26)
* do "$prog/school-trend.do"                  // pre-trend (also App 25-26)

* ---- Table 10 : Attendance & discipline DiD (HOU) -----------------------------
* (produced by katrina_by_quartiles_va_grade_statestd.do +
*  katrina_iv_gender_ethnicity_noshelter_grade.do -- run above)


*===============================================================================
* PART E. APPENDIX TABLES (group by driver file; full map in README)
*-------------------------------------------------------------------------------
* --- Houston achievement specification battery (App Tables 4 & 5; behavior App 41)
* do "$prog/katrina_iv_c.do"
* do "$prog/katrina_by_quartiles_va_fe.do"
* do "$prog/katrina_by_quartiles_va_class.do"
* do "$prog/katrina_by_quartiles_va_outlier.do"
* do "$prog/katrina_by_quartiles_va_intpanel.do"
* do "$prog/katrina_by_quartiles_0405inst.do"
* do "$prog/katrina_by_quartiles_va_scale.do"
* do "$prog/katrina_by_quartiles_attrition.do"
* do "$prog/katrina_by_quartiles_va_grade_altstd.do"
* do "$prog/katrina_by_quartiles_va_campusyear.do"
* do "$prog/katrina_by_quartiles_va_campusgrade.do"
* do "$prog/katrina_by_quartiles_va_totenroll.do"
* do "$prog/katrina_by_quartiles_va_newentrant.do"
* do "$prog/katrina_by_quartiles_va_nozero.do"

* --- App 3 (HOU reduced form) ; App 6 (quintiles) -----------------------------
* do "$prog/katrina_by_quartiles_va.do"
* do "$prog/katrina_by_quartiles_va_quintiles.do"

* --- App 7 & 8 & 42 (enrollment-disruption) -----------------------------------
* do "$prog/katrina_by_quartiles_avgweeklyenroll_b.do"
* do "$prog/katrina_by_quartiles_halfyear_enroll.do"

* --- App 11 (test-taking / selection into testing) ----------------------------
* do "$prog/katrina_by_quartiles_testtaking.do"
* do "$prog/check_non_test_takers2.do"

* --- LA quartile-analysis variants --------------------------------------------
* do "$prog/quartile_analysis_revision_full_trends_b.do"  // App 23-24 (school trends)
* do "$prog/quartile_analysis_revision_full_scale.do"     // App 29 (unstandardized)
* do "$prog/quartile_analysis_revision_full_FE_b.do"      // App 31 (student FE)
* do "$prog/quartile_analysis_revision_alt_standard2.do"  // App 38 (alt standardization)
* do "$prog/quartile_analysis_revision_quintiles.do"      // App 36 (quintiles)

* --- App 44 (class sizes) ; App 45 (resources) ; App 46 (switching) -----------
* do "$prog/analyze_school_level2_quartiles_b.do"
* do "$prog/katrina_resources.do"
* do "$prog/katrina_by_quartiles_leave.do"

* (Robustness variants ending in _nolag / _nolagint feed the corresponding
*  "no-lag" / "lag-not-interacted" rows of App Tables 4, 5, 9, 10, 12, 13.)


*===============================================================================
* END OF MASTER. See README.md for the full file->table map and the step-by-step
* guide to extending the analysis to additional school years.
*===============================================================================
