/**********************************************************************
* Program : mh.sas
* Domain  : MH — Medical History
* Purpose : Create SDTM MH domain from raw EDC data
***********************************************************************/

libname raw  "/data/raw/edc";
libname sdtm "/data/sdtm";

data work.mh_raw;
  set raw.mh;
  where mhterm ne "";
run;

data work.mh_sdtm;
  set work.mh_raw;
  STUDYID  = "STUDY001";
  DOMAIN   = "MH";
  MHSEQ    = _N_;
  MHTERM   = strip(mhterm);
  MHDECOD  = strip(mhdecod);
  MHBODSYS = strip(mhbodsys);
  MHSTDTC  = strip(mhstdtc);
  MHENDTC  = strip(mhendtc);
  MHENRTPT = upcase(strip(mhenrtpt));
  MHPRESP  = upcase(strip(mhpresp));
  MHOCCUR  = upcase(strip(mhoccur));
run;

data sdtm.mh;
  set work.mh_sdtm;
  keep STUDYID DOMAIN USUBJID MHSEQ MHTERM MHDECOD MHBODSYS
       MHSTDTC MHENDTC MHENRTPT MHPRESP MHOCCUR;
run;

%put NOTE: MH domain complete.;
