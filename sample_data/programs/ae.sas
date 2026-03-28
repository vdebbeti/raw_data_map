/**********************************************************************
* Program : ae.sas
* Domain  : AE — Adverse Events
* Purpose : Create SDTM AE domain from raw EDC data
***********************************************************************/

options compress=yes;

libname raw  "/data/raw/edc";
libname sdtm "/data/sdtm";

/*--- Step 1: Read raw AE data ----------------------------------------*/
data work.ae_input;
  set raw.ae;
  where aeterm ne "";
  /* Standardise missing dates */
  if aestdtc = "" then aestdtc = "UNKNOWN";
run;

/*--- Step 2: Pull subject-level demographics for merge ---------------*/
proc sort data = raw.dm (keep = usubjid rfstdtc siteid) out = work.dm_ref;
  by usubjid;
run;

/*--- Step 3: Map raw variables to SDTM AE variables -----------------*/
data work.ae_mapped;
  merge work.ae_input (in=a)
        work.dm_ref   (in=b);
  by usubjid;
  if a;

  /* Required SDTM variables */
  STUDYID  = "STUDY001";
  DOMAIN   = "AE";
  AESEQ    = _N_;
  AETERM   = strip(aeterm);
  AEDECOD  = strip(aedecod);
  AEBODSYS = strip(aebodsys);
  AESEV    = upcase(strip(aesev));
  AESER    = upcase(strip(aeser));
  AESTDTC  = strip(aestdtc);
  AEENDTC  = strip(aeendtc);
  AEOUT    = upcase(strip(aeout));
  AEREL    = upcase(strip(aerel));
  AEACN    = upcase(strip(aeacn));

run;

/*--- Step 4: Output to SDTM library ---------------------------------*/
data sdtm.ae;
  retain STUDYID DOMAIN USUBJID AESEQ AETERM AEDECOD AEBODSYS
         AESEV AESER AESTDTC AEENDTC AEOUT AEREL AEACN;
  set work.ae_mapped;
  keep STUDYID DOMAIN USUBJID AESEQ AETERM AEDECOD AEBODSYS
       AESEV AESER AESTDTC AEENDTC AEOUT AEREL AEACN;
run;

proc print data=sdtm.ae (obs=10); run;

%put NOTE: AE domain complete. N=%trim(%left(%sysfunc(countobs(sdtm.ae))));
