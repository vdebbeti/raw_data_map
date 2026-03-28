/**********************************************************************
* Program : ds.sas
* Domain  : DS — Disposition
* Purpose : Create SDTM DS domain from raw EDC data
***********************************************************************/

libname raw  "/data/raw/edc";
libname sdtm "/data/sdtm";

data work.ds_raw;
  set raw.ds;
  where dsterm ne "";
run;

data work.ds_sdtm;
  set work.ds_raw;
  STUDYID  = "STUDY001";
  DOMAIN   = "DS";
  DSSEQ    = _N_;
  DSTERM   = upcase(strip(dsterm));
  DSDECOD  = strip(dsdecod);
  DSCAT    = strip(dscat);
  DSSCAT   = strip(dsscat);
  DSDTC    = strip(dsdtc);
  DSDY     = input(strip(dsdy_c), best.);
  EPOCH    = strip(epoch);
run;

data sdtm.ds;
  set work.ds_sdtm;
  keep STUDYID DOMAIN USUBJID DSSEQ DSTERM DSDECOD DSCAT DSSCAT DSDTC DSDY EPOCH;
run;

%put NOTE: DS domain complete.;
