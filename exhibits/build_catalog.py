#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
build_catalog.py — Build the filterable exhibit catalog for the Katrina paper.

Captures every table/figure from the published AER PDF (and the appendix PDF)
as a cropped page PDF + a PNG, attaches the originating Stata program(s) and a
representative code snippet, an analysis-type tagging, and a good-practice
evaluation, separating MAIN-body exhibits from APPENDIX exhibits.

No Stata is run: the micro-data are proprietary (HISD + Louisiana DOE), so the
exhibits are captured from the paper (the user's "option 2") and paired with the
exact package code that produces them.

Outputs:
  exhibits/main/<id>.pdf , exhibits/main/<id>.png
  exhibits/appendix/<id>.pdf , exhibits/appendix/<id>.png
  exhibits/catalog.json
"""
import json, os, re, subprocess, sys, shutil

ROOT = "/Users/jostin.kitmang/Downloads/Imberman Replication"
PAPER = os.path.join(ROOT, "imberman-kugler-sacerdote-2012-aer.pdf")
APPDX = os.path.join(ROOT, "20091305_app.pdf")
PROG = os.path.join(ROOT, "programs")
OUT = os.path.join(ROOT, "exhibits")
DPI = 120

# ---------------------------------------------------------------- tag vocab
TAGS = {
    "map": "Descriptive figure (map)",
    "summary": "Summary statistics",
    "olsfe": "OLS + fixed effects",
    "rf": "Reduced form",
    "iv": "IV / 2SLS",
    "lim": "Linear-in-means peer effects",
    "quartile": "Quartile heterogeneity",
    "tests": "Model specification tests",
    "placebo": "Placebo / robustness",
    "school": "School-level aggregate",
    "nontest": "Non-test outcomes",
}

# ---------------------------------------------------------------- MAIN spec
MAIN = [
    dict(id="fig1", num="Figure 1", kind="figure", pages=[5],
         title="Hurricane Katrina and Rita Evacuees in HISD by School, 2005–2006",
         tags=["map"], programs=[], exports=False,
         eval=[
            "Leads with geography: a school-level map orients the reader to the identifying variation (where evacuees landed) before any regression — textbook 'motivate the design first'.",
            "Encodes intensity by shading, so the eye reads concentration without a table of shares.",
            "Improvement: a companion histogram of the evacuee-share distribution would quantify the variation the map shows qualitatively.",
         ]),
    dict(id="fig2", num="Figure 2", kind="figure", pages=[6],
         title="Hurricanes Katrina and Rita Evacuees in Louisiana by School, 2005–2006",
         tags=["map"], programs=[], exports=False,
         eval=[
            "Mirrors Figure 1 for the second dataset (Louisiana), giving the two-state design a parallel visual grammar — consistency across exhibits lowers reader load.",
            "The notes flag excluded high-evacuee and Rita-landfall schools, making sample construction transparent on the figure itself.",
            "Improvement: a shared legend/scale across Figures 1–2 would make the two states directly comparable.",
         ]),
    dict(id="t1", num="Table 1", kind="table", pages=[13],
         title="Characteristics of Evacuees and Incumbent Louisiana and Houston Students",
         tags=["summary"], programs=["summary_stats_la.do", "sumstats_houston.do", "sumstats_b.do"], exports=False,
         eval=[
            "Classic Table 1: means/SDs for evacuees vs incumbents in both states, so the reader sizes selection before causal claims.",
            "Columns mirror the two estimation samples (LA, HOU), matching the table to the analysis that follows.",
            "Reporting note: it is a descriptive table by design — no SEs/stars needed; the comparison of group means is the message.",
            "Improvement: a normalized-difference column would summarize imbalance in one glance (Imbens–Wooldridge).",
         ]),
    dict(id="t2", num="Table 2", kind="table", pages=[14],
         title="Regressions of Test Scores on Katrina/Rita Evacuee Status Dummy",
         tags=["olsfe"], programs=["analysis_revision_linear.do", "katrina_nonkatrina.do"], exports=False,
         eval=[
            "Builds from a raw evacuee–native gap to FE-adjusted gaps in progressive columns, the canonical 'add controls across columns' structure.",
            "School fixed effects isolate within-school comparisons, and the column layout makes the identifying variation legible.",
            "Reports SEs and sample sizes per column; the reader can see how the estimate moves as FE are added.",
            "Improvement: a control-mean-of-DV row would anchor the magnitude of the gap.",
         ]),
    dict(id="t3", num="Table 3", kind="table", pages=[15],
         title="Reduced-Form Estimates of Evacuee Share of Enrollment in Grade (Houston)",
         tags=["rf", "iv", "olsfe"], programs=["katrina_by_quartiles_va_grade_statestd.do", "katrina_iv_gender_ethnicity_noshelter_grade.do", "katrina_placebotest_grade.do"], exports=False,
         eval=[
            "The identification workhorse: reduced-form effect of grade-level evacuee share on incumbent achievement, with the Sept-13 share as the instrument for re-sorting.",
            "Includes a placebo column (pre-period share) — defending the design inside the same table is good practice.",
            "Grade×year and school FE rows tell the reader exactly what variation is used.",
            "Improvement: showing the first-stage F alongside the 2SLS column would let readers judge instrument strength without leaving the table.",
         ]),
    dict(id="t4", num="Table 4", kind="table", pages=[18],
         title="Linear-in-Means Models of Peer Effects in Achievement for Houston",
         tags=["lim", "iv", "olsfe"], programs=["katrina_by_quartiles_lim_test_fullint_math.do", "katrina_by_quartiles_lim_test_fullint_read.do"], exports=False,
         note_map="Per the package author's program→table map (numbering follows the working paper for the two linear-in-means tables).",
         eval=[
            "Estimates the linear-in-means peer model for Houston — the simplest peer structure, shown first so richer models in later tables have a baseline.",
            "Separate math and reading columns keep subjects un-pooled, respecting that peer effects can differ by domain.",
            "Improvement: the linear-in-means coefficient is only interpretable against the nonlinear models (Table 7); a cross-reference in the notes would help.",
         ]),
    dict(id="t5", num="Table 5", kind="table", pages=[21],
         title="Reduced-Form Estimates of Evacuee Share of Enrollment in Grade (Louisiana)",
         tags=["rf", "quartile", "olsfe"], programs=["analysis_revision_linear.do", "quartile_analysis_revision_d.do"], exports=True,
         eval=[
            "The Louisiana analog of Table 3, enabling a two-state replication of the headline reduced-form result — replication within the paper is itself a credibility device.",
            "Introduces the 4×4 quartile structure that the paper's peer-structure tests rely on.",
            "Exports directly via the workhorse quartile program, so the printed numbers are traceable to a single script.",
            "Improvement: the 4×4 cells are dense; a heat-map companion figure would make the interaction pattern pop for presentations.",
         ]),
    dict(id="t6", num="Table 6", kind="table", pages=[22, 23],
         title="Linear-in-Means Models of Peer Effects in Achievement for Louisiana",
         tags=["lim", "olsfe"], programs=["epple_romano_f_ela_grade_fullintb.do", "epple_romano_f_math_grade_fullintb.do"], exports=False,
         eval=[
            "Louisiana linear-in-means estimates (Epple–Romano form), parallel to Table 4 for Houston — consistent structure across states.",
            "The own-quartile interactions are spelled out, making the functional form explicit rather than buried in text.",
            "Spans two pages; a tighter column set or an appendix overflow would improve at-a-glance readability.",
         ]),
    dict(id="t7", num="Table 7", kind="table", pages=[25],
         title="Nonlinear Models of Evacuee Share and Achievement on Incumbent Outcomes",
         tags=["quartile", "olsfe"], programs=["quartile_analysis_revision_d.do"], exports=True,
         eval=[
            "The paper's intellectual core: nonlinear (quartile-interacted) peer effects that distinguish linear-in-means from bad-apple and invidious-comparison models.",
            "The 4×4 design directly maps theory to coefficients — each cell answers a specific peer-structure question.",
            "Produced by the single workhorse script, so every cell is reproducible from one file (good provenance).",
            "Improvement: significant cells could be shaded to guide the reader through a large coefficient matrix.",
         ]),
    dict(id="t8", num="Table 8", kind="table", pages=[27],
         title="Tests of Models of Peer Effects Using Estimates from Table 7",
         tags=["tests"], programs=["quartile_analysis_revision_full_b_tests_nobon.do"], exports=False,
         eval=[
            "Turns estimates into formal model selection: linear restrictions (test/lincom) that reject or fail to reject each peer-structure model.",
            "Pairing an estimate table (T7) with a dedicated test table (T8) is exemplary — it separates 'what we estimated' from 'what it implies'.",
            "Reports the hypotheses explicitly so the reader can audit the mapping from theory to restriction.",
            "Improvement: a multiple-testing note (the package has a Bonferroni variant) would preempt the 'many tests' critique.",
         ]),
    dict(id="t9", num="Table 9", kind="table", pages=[29],
         title="School-Level Placebo Test Regressions of School Performance Score",
         tags=["placebo", "school"], programs=["school_level_placebo_b.do", "school-trend.do"], exports=False,
         eval=[
            "A placebo at the school level: if evacuee shares predicted aggregate school scores mechanically, the design would be suspect — this table checks that.",
            "Aggregating to school level is the right unit for the placebo and is clearly labeled as such.",
            "Improvement: pairing with a pre-trend figure would make the 'no effect where there should be none' point visually, not just in coefficients.",
         ]),
    dict(id="t10", num="Table 10", kind="table", pages=[31],
         title="Estimates of Evacuee Share on Incumbent Attendance and Discipline",
         tags=["iv", "nontest", "olsfe"], programs=["katrina_by_quartiles_va_grade_statestd.do", "katrina_iv_gender_ethnicity_noshelter_grade.do"], exports=False,
         eval=[
            "Extends the design to non-test outcomes (attendance, discipline), showing the peer mechanism is not a test-score artifact — good for external validity.",
            "Reuses the Table 3 specification, so the reader reads it quickly by analogy.",
            "Improvement: stating the control mean for each behavioral outcome would make the effect sizes interpretable (e.g., days absent).",
         ]),
]

# ------------------------------------------------------- APPENDIX program map
A_PROGRAMS = {
    2: ["sumstats_b.do", "summary_stats_la.do"],
    3: ["katrina_by_quartiles_va.do", "katrina_iv_gender_ethnicity_noshelter.do"],
    4: ["katrina_iv_c.do", "katrina_by_quartiles_va_fe.do", "katrina_by_quartiles_va_outlier.do"],
    5: ["katrina_iv_c.do", "katrina_by_quartiles_va_class.do", "katrina_by_quartiles_va_intpanel.do"],
    6: ["katrina_by_quartiles_va_quintiles.do"],
    7: ["katrina_by_quartiles_avgweeklyenroll_b.do"],
    8: ["katrina_by_quartiles_halfyear_enroll.do"],
    9: ["katrina_by_quartiles_lim_test_fullint_math.do", "katrina_by_quartiles_lim_test_fullint_read.do"],
    10: ["katrina_by_quartiles_lim_test_fullint_math.do", "katrina_by_quartiles_lim_test_fullint_read.do"],
    11: ["katrina_by_quartiles_testtaking.do", "check_non_test_takers2.do"],
    12: ["analysis_revision_linear.do", "quartile_analysis_revision_d.do"],
    13: ["analysis_revision_linear.do", "quartile_analysis_revision_d.do"],
    14: ["epple_romano_f_ela_grade_fullintb.do", "epple_romano_f_math_grade_fullintb.do"],
    20: ["quartile_analysis_revision_full_b_tests_nobon.do"],
    23: ["quartile_analysis_revision_full_trends_b.do"],
    24: ["quartile_analysis_revision_full_trends_b.do"],
    25: ["school_level_placebo_b.do", "school-trend.do"],
    26: ["school_level_placebo_b.do", "school-trend.do"],
    29: ["quartile_analysis_revision_full_scale.do"],
    31: ["quartile_analysis_revision_full_FE_b.do"],
    38: ["quartile_analysis_revision_alt_standard2.do"],
    40: ["katrina_iv_gender_ethnicity_noshelter_grade.do"],
    42: ["katrina_by_quartiles_avgweeklyenroll_b.do"],
    44: ["analyze_school_level2_quartiles_b.do"],
    45: ["katrina_resources.do"],
    46: ["katrina_by_quartiles_leave.do"],
}
A_WORKHORSE = [15, 16, 17, 18, 19, 21, 22, 27, 28, 30, 32, 33, 34, 35, 36, 37, 39, 43]
for n in A_WORKHORSE:
    A_PROGRAMS[n] = ["quartile_analysis_revision_d.do"]
A_EXPORTS = {8, 12, 13, 29, 38, 40, 45} | set(A_WORKHORSE)  # write .xls directly

def appendix_tags(title):
    t = title.lower(); out = []
    if "reduced form" in t: out.append("rf")
    if "specification test" in t or "robust" in t or "outlier" in t or "trend" in t or "alternative" in t or "attrition" in t: out.append("placebo")
    if "quartile" in t or "nonlinear" in t or "4" in t: out.append("quartile")
    if "school level" in t or "school-level" in t or "class size" in t: out.append("school")
    if "linear" in t and "means" in t: out.append("lim")
    if "characteristics" in t or "observation counts" in t or "descriptive" in t: out.append("summary")
    if "resource" in t or "staffing" in t or "switching" in t or "attendance" in t or "discipline" in t or "class size" in t: out.append("nontest")
    if "test" in t and ("model" in t or "peer" in t): out.append("tests")
    return out or ["quartile"]

# ---------------------------------------------------------------- helpers
def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True)

def page_title(pdf, page, pat):
    r = run(["pdftotext", "-f", str(page), "-l", str(page), "-layout", pdf, "-"])
    for line in r.stdout.splitlines():
        m = re.search(pat, line, re.I)
        if m:
            s = line[m.start():].strip()
            s = re.sub(r"\s+", " ", s)
            return s[:140]
    return ""

def capture(pdf, pages, dest_base):
    """Make dest_base.pdf (cropped) and dest_base.png from the given page(s)."""
    tmp = dest_base + "._raw.pdf"
    # extract pages into a single pdf
    if len(pages) == 1:
        run(["pdfseparate", "-f", str(pages[0]), "-l", str(pages[0]), pdf, tmp])
    else:
        parts = []
        for i, p in enumerate(pages):
            pp = f"{dest_base}._p{i}.pdf"
            run(["pdfseparate", "-f", str(p), "-l", str(p), pdf, pp]); parts.append(pp)
        run(["gs", "-q", "-dNOPAUSE", "-dBATCH", "-sDEVICE=pdfwrite", f"-sOutputFile={tmp}"] + parts)
        for pp in parts:
            if os.path.exists(pp): os.remove(pp)
    # crop margins
    cropped = dest_base + ".pdf"
    cr = run(["pdfcrop", "--margins", "6", tmp, cropped])
    if not os.path.exists(cropped):
        shutil.copy(tmp, cropped)
    # png for the web
    run(["pdftoppm", "-png", "-r", str(DPI), "-singlefile", cropped, dest_base])
    if os.path.exists(tmp): os.remove(tmp)
    return os.path.exists(cropped)

def snippet(programs):
    """Representative exporting/estimation lines from the first program."""
    if not programs: return ""
    path = os.path.join(PROG, programs[0])
    if not os.path.exists(path): return ""
    keep = []
    pat = re.compile(r"^\s*(xi:|areg|reg |regress|ivreg|ivregress|ivreg2|xtreg|collapse|outreg2|esttab|test |lincom|graph export|putexcel)", re.I)
    with open(path, errors="ignore") as f:
        for line in f:
            if pat.search(line):
                keep.append(line.rstrip()[:160])
            if len(keep) >= 10: break
    return "\n".join(keep)

# ---------------------------------------------------------------- build
def main():
    os.makedirs(os.path.join(OUT, "main"), exist_ok=True)
    os.makedirs(os.path.join(OUT, "appendix"), exist_ok=True)
    catalog = {"paper": "Imberman, Kugler & Sacerdote (2012). \"Katrina's Children: Evidence on the Structure of Peer Effects from Hurricane Evacuees.\" American Economic Review 102(5): 2048–2082.",
               "doi": "10.1257/aer.102.5.2048",
               "note": "Exhibits captured from the published AER PDF and appendix (micro-data are proprietary, so they are not re-run). Each exhibit is paired with the package program(s) that produce it. Code mapping follows the package README §8.",
               "tagLabels": TAGS, "exhibits": []}

    # MAIN
    for ex in MAIN:
        base = os.path.join(OUT, "main", ex["id"])
        ok = capture(PAPER, ex["pages"], base)
        print(("  ok " if ok else " FAIL "), ex["num"], ex["pages"])
        catalog["exhibits"].append({
            "id": ex["id"], "num": ex["num"], "kind": ex["kind"], "section": "main",
            "title": ex["title"], "pages": ex["pages"], "tags": ex["tags"],
            "programs": ex["programs"], "exports": ex.get("exports", False),
            "snippet": snippet(ex["programs"]), "evaluation": ex["eval"],
            "noteMap": ex.get("note_map", ""),
            "pdf": f"exhibits/main/{ex['id']}.pdf", "png": f"exhibits/main/{ex['id']}.png",
        })

    # APPENDIX (one table per page; A_n on page n+6)
    for n in range(1, 47):
        page = n + 6
        ex_id = f"a{n}"
        base = os.path.join(OUT, "appendix", ex_id)
        ok = capture(APPDX, [page], base)
        title = page_title(APPDX, page, r"appendix table\s*%d" % n)
        title = re.sub(r"^appendix table\s*%d\s*[-:.]?\s*" % n, "", title, flags=re.I).strip() or f"Appendix Table {n}"
        progs = A_PROGRAMS.get(n, [])
        tags = appendix_tags(title)
        print(("  ok " if ok else " FAIL "), f"A{n}", page, "-", title[:48])
        catalog["exhibits"].append({
            "id": ex_id, "num": f"Appendix Table {n}", "kind": "table", "section": "appendix",
            "title": title, "pages": [page], "tags": tags,
            "programs": progs, "exports": n in A_EXPORTS,
            "snippet": snippet(progs),
            "evaluation": [
                f"Appendix robustness/extension exhibit ({TAGS[tags[0]]}). Supports a main-text result by varying specification, sample, or outcome.",
                ("Exports directly to a file via the package script — fully traceable." if n in A_EXPORTS
                 else "Printed to the Stata log in the package and hand-collected into the published table."),
            ],
            "noteMap": "",
            "pdf": f"exhibits/appendix/{ex_id}.pdf", "png": f"exhibits/appendix/{ex_id}.png",
        })

    with open(os.path.join(OUT, "catalog.json"), "w") as f:
        json.dump(catalog, f, indent=1, ensure_ascii=False)
    print(f"\nWrote {len(catalog['exhibits'])} exhibits → exhibits/catalog.json")

if __name__ == "__main__":
    main()
