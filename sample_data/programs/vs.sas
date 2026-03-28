/**********************************************************************
* Program : vs.sas
* Domain  : VS — Vital Signs
* Purpose : Create SDTM VS domain from raw EDC data
***********************************************************************/

libname raw  "/data/raw/edc";
libname sdtm "/data/sdtm";

data work.vs_raw;
  set raw.vs;
  where vstestcd ne "";
run;

data work.vs_sdtm;
  set work.vs_raw;
  STUDYID  = "STUDY001";
  DOMAIN   = "VS";
  VSSEQ    = _N_;
  VSTESTCD = upcase(strip(vstestcd));
  VSTEST   = strip(vstest);
  VSORRES  = strip(vsorres);
  VSORRESU = strip(vsorresu);
  VSSTRESN = input(vsorres, ?? best.);
  VSSTRESU = strip(vsstresu);
  VSDTC    = strip(vsdtc);
  VSBLFL   = strip(vsblfl);
  VISITNUM = input(strip(visitnum_c), best.);
  VISIT    = strip(visit);
run;

data sdtm.vs;
  set work.vs_sdtm;
  keep STUDYID DOMAIN USUBJID VSSEQ VSTESTCD VSTEST VSORRES VSORRESU
       VSSTRESN VSSTRESU VSDTC VSBLFL VISITNUM VISIT;
run;

%put NOTE: VS domain complete.;
