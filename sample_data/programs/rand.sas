/**********************************************************************
* Program : rand.sas
* Domain  : RAND — Randomization (Trial Design)
* Purpose : Create randomization dataset — references raw.randomization
*           NOTE: raw.randomization not yet delivered in EDC extract
***********************************************************************/

libname raw  "/data/raw/edc";
libname sdtm "/data/sdtm";

/* Randomization data — awaiting final data transfer */
data work.rand_raw;
  set raw.randomization;    /* <-- Code-Only: file not yet in raw folder */
run;

data work.rand_sdtm;
  set work.rand_raw;
  STUDYID = "STUDY001";
  DOMAIN  = "RAND";
run;

%put NOTE: RAND processing complete.;
