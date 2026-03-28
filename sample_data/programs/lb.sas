/**********************************************************************
* Program : lb.sas
* Domain  : LB — Laboratory Test Results
* Purpose : Create SDTM LB domain merging EDC labs with external
*           hormone and biomarker datasets
***********************************************************************/

libname raw     "/data/raw/edc";
libname rawext  "/data/raw/external";
libname sdtm    "/data/sdtm";

/*--- Step 1: Read core lab data from EDC ----------------------------*/
data work.lb_edc;
  set raw.lb;
  source = "EDC";
run;

/*--- Step 2: Read hormone data (external dataset) -------------------*/
data work.hormones;
  set raw.hormones;          /* <-- external hormones dataset */
  source = "EXTERNAL";
  LBTESTCD = "HORMONE";
  LBTEST   = strip(hormone);
  LBORRES  = strip(put(value, best.));
  LBORRESU = strip(unit);
  LBCAT    = "HORMONES";
run;

/*--- Step 3: Read biomarker data (external dataset) -----------------*/
data work.biomarkers;
  set raw.biomarkers;        /* <-- external biomarkers dataset */
  source = "EXTERNAL";
  LBTESTCD = upcase(strip(biomarker));
  LBTEST   = strip(biomarker);
  LBORRES  = strip(result);
  LBORRESU = strip(unit);
  LBCAT    = "BIOMARKERS";
run;

/*--- Step 4: Vertically combine all lab sources ---------------------*/
data work.lb_all;
  set work.lb_edc
      work.hormones
      work.biomarkers;
run;

/*--- Step 5: Derive SDTM variables -----------------------------------*/
data work.lb_sdtm;
  set work.lb_all;
  STUDYID  = "STUDY001";
  DOMAIN   = "LB";
  LBSEQ    = _N_;
  LBSTRESN = input(LBORRES, ?? best.);
  LBSTRESU = strip(LBORRESU);
  LBSTNRHI = strip(lbstnrhi);
  LBSTNRLO = strip(lbstnrlo);
  LBNRIND  = strip(lbnrind);
  LBDTC    = strip(lbdtc);
  VISITNUM = input(strip(visitnum_c), best.);
  VISIT    = strip(visit);
run;

/*--- Step 6: Output to SDTM library ---------------------------------*/
data sdtm.lb;
  retain STUDYID DOMAIN USUBJID LBSEQ LBTESTCD LBTEST LBCAT
         LBORRES LBORRESU LBSTRESN LBSTRESU LBNRIND LBDTC VISITNUM VISIT;
  set work.lb_sdtm;
  keep STUDYID DOMAIN USUBJID LBSEQ LBTESTCD LBTEST LBCAT
       LBORRES LBORRESU LBSTRESN LBSTRESU LBNRIND LBDTC VISITNUM VISIT;
run;

%put NOTE: LB domain complete.;
