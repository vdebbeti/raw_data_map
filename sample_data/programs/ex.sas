/**********************************************************************
* Program : ex.sas
* Domain  : EX — Exposure
* Purpose : Create SDTM EX domain from raw EDC data
***********************************************************************/

libname raw  "/data/raw/edc";
libname sdtm "/data/sdtm";

data work.ex_raw;
  set raw.ex;
  where extrt ne "";
run;

data work.ex_sdtm;
  set work.ex_raw;
  STUDYID  = "STUDY001";
  DOMAIN   = "EX";
  EXSEQ    = _N_;
  EXTRT    = strip(extrt);
  EXDOSE   = input(strip(exdose_c), best.);
  EXDOSU   = strip(exdosu);
  EXDOSFRM = upcase(strip(exdosfrm));
  EXROUTE  = upcase(strip(exroute));
  EXSTDTC  = strip(exstdtc);
  EXENDTC  = strip(exendtc);
  VISITNUM = input(strip(visitnum_c), best.);
  VISIT    = strip(visit);
run;

data sdtm.ex;
  set work.ex_sdtm;
  keep STUDYID DOMAIN USUBJID EXSEQ EXTRT EXDOSE EXDOSU EXDOSFRM
       EXROUTE EXSTDTC EXENDTC VISITNUM VISIT;
run;

%put NOTE: EX domain complete.;
