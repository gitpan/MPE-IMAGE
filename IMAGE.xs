#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"


  #define make_int(var,index) (var[index] << 16) | (var[index+1] & 0xffff)

  void setstatus(short *status) {
    int  cnt;
    AV  *status_array;
    SV **sv_ptr;

    status_array = get_av("MPE::IMAGE::DbStatus",TRUE);
    /* Make sure we have enough entries */
    if (av_len(status_array) < 9) {
      av_unshift(status_array,10 - (av_len(status_array)+1));
    }
    for (cnt = 0; cnt < 10; cnt++) {
      if ((sv_ptr = av_fetch(status_array,cnt,FALSE)) == NULL) {
        av_store(status_array,cnt,newSViv(status[cnt]));
      } else {
        sv_setiv(*sv_ptr,status[cnt]);
      } 
    }
  } /* setstatus */

  void setDbError(SV *ErrPtr) {
    int    cnt;
    short  dbstatus[10];
    char   error[73];
    short  error_len;
    AV    *status_array;
    SV    *DbError;
    SV   **sv_ptr;

    DbError = SvRV(ErrPtr);
    status_array = get_av("MPE::IMAGE::DbStatus",FALSE);
    if (status_array == NULL ||
        av_len(status_array) < 9 ||
        SvIV(*av_fetch(status_array,0,FALSE)) == 0) {
      sv_setiv(DbError,0);
      sv_setpvn(DbError,"",0);
      SvIOK_on(DbError);
    } else {
      for (cnt = 0; cnt < 10; cnt++) {
        sv_ptr = av_fetch(status_array,cnt,FALSE);
        dbstatus[cnt] = SvIV(*sv_ptr);
      }
      dberror(dbstatus,error,&error_len);
      sv_setiv(DbError,dbstatus[0]);
      sv_setpvn(DbError,error,error_len);
      SvIOK_on(DbError);
    }
  } /* setDbError */

  void DbExplain() {
    int    cnt;
    short  dbstatus[10];
    AV    *status_array;
    SV   **sv_ptr;

    status_array = get_av("MPE::IMAGE::DbStatus",FALSE);
    if (status_array != NULL && av_len(status_array) >= 9) {
      for (cnt = 0; cnt < 10; cnt++) {
        sv_ptr = av_fetch(status_array,cnt,FALSE);
        dbstatus[cnt] = SvIV(*sv_ptr);
      }
      dbexplain(dbstatus);
    }
  } /* DbExplain */

  void _dbclose(SV *basehandle, SV *dataset, short mode) {
    short    status[10];
    SV     **entry;
    STRLEN   len;
    char    *dset_buf;

    entry = hv_fetch((HV *)SvRV(basehandle),"handle",6,FALSE);
    if (entry == NULL) {
      croak("DbClose called without valid handle.");
    } else {
      if (*entry == NULL) {
        croak("*entry is NULL");
      }
      if (SvIOK(dataset) || looks_like_number(dataset)) {
        dset_buf = malloc(4);
        *(int *)dset_buf = SvIV(dataset);
      } else {
        dset_buf = SvPV_nolen(dataset);
      }
      dbclose(SvPV_nolen(*entry),dset_buf,&mode,status);
      setstatus(status);
      if (status[0] == 0 && mode == 1) {
        hv_store((HV *)SvRV(basehandle),"closed",6,&PL_sv_undef,0);
      }
    }
  } /* _dbclose */

  void _dbfind(SV *basehandle, SV *dataset, short mode, SV *item,
               SV *argument) {
    short   status[10];
    SV    **entry;
    char   *dset_buf;
    char   *item_buf;

    entry = hv_fetch((HV *)SvRV(basehandle),"handle",6,FALSE);
    if (entry == NULL) {
      croak("DbGet called without valid handle.");
    } 

    if (SvIOK(dataset) || looks_like_number(dataset)) {
      dset_buf = malloc(2);
      *(short *)dset_buf = SvIV(dataset);
    } else {
      dset_buf = SvPV_nolen(dataset);
    }

    if (SvIOK(item) || looks_like_number(item)) {
      item_buf = malloc(2);
      *(short *)item_buf = SvIV(item);
    } else {
      item_buf = SvPV_nolen(item);
    }

    dbfind(SvPV_nolen(*entry),dset_buf,&mode,status,item_buf,
           SvPV_nolen(argument));
    setstatus(status);
  } /* _dbfind */
    
  SV *_dbget(SV *basehandle, SV *dataset, short mode, SV *list, 
             SV *argument, int size) {
    int     cnt;
    short   status[10];
    char   *buffer;
    SV    **entry;
    short  *list_buffer;
    AV     *list_array;
    char   *dset_buf;
    SV     *ret_sv;

    entry = hv_fetch((HV *)SvRV(basehandle),"handle",6,FALSE);
    if (entry == NULL) {
      croak("DbGet called without valid handle.");
    } 
    if (size > 0) {
      buffer = malloc(size);
    } else {
      buffer = malloc(1);
    }
    if (buffer == NULL) {
      croak("Unable to malloc %d bytes in DbGet",size);
    }
    if (SvROK(list)) { /* Got a list of item numbers */
      list_array = (AV *)SvRV(list);
      list_buffer = calloc(av_len(list_array)+2,2);
      list_buffer[0] = av_len(list_array)+1;
      for (cnt = 1; cnt <= list_buffer[0]; cnt++) {
        list_buffer[cnt] = SvIV(*av_fetch(list_array,cnt-1,FALSE));
      }
    } else {
      (char *)list_buffer = SvPV_nolen(list);
    }
    if (SvIOK(dataset) || looks_like_number(dataset)) {
      dset_buf = malloc(2);
      *(short *)dset_buf = SvIV(dataset);
    } else {
      dset_buf = SvPV_nolen(dataset);
    }

    dbget(SvPV_nolen(*entry),dset_buf,&mode,status,list_buffer,buffer,
          SvPV_nolen(argument));
    setstatus(status);
    
    if (SvROK(list)) {
      free(list_buffer);
    }
    if (buffer != NULL) {
      ret_sv = newSVpvn(buffer,size);
      free(buffer);
      return(ret_sv);
    } else {
      return(&PL_sv_undef);
    }
  } /* _dbget */

  SV *_dbinfo(SV *basehandle, SV *qualifier, short mode) {
    int     cnt;
    short   status[10];
    short   qual_short;
    short  *buffer;
    AV     *new_array;
    HV     *new_hash;
    char   *char_ptr;
    SV     *temp_sv;
    SV     *return_sv;;
    
    if ( mode < 101  || (mode > 104 &&
         mode < 201) || (mode > 206 &&
         mode < 301) || (mode > 302 &&
         mode < 406) || (mode > 406 &&
         mode < 501) || (mode > 501 &&
         mode < 901) ||  mode > 901 ) {
      warn("DbInfo can only handle the following modes:\n");
      warn("  101-104, 201-206, 301-302, 406, 501, 901\n");
      warn("Ignoring DbInfo call with mode %d",mode);
      return(&PL_sv_undef);
    }

    /* 
       Maxima:
        240 datasets per database
       1200 items per database
        255 items per dataset
         64 paths per master dataset
         16 paths per detail dataset
     */
       
    if (mode == 101 || 
        mode == 201 || mode == 206 ||
        mode == 501 || 
        mode == 901) {
      buffer = calloc(1,2);
    } else if (mode == 302) {
      buffer = calloc(2,2);
    } else if (mode == 102 || 
               mode == 202 || mode == 205 ||
               mode == 406) {
      buffer = calloc(32,2);
    } else if (mode == 301) {
      buffer = calloc(193,2);
    } else if (mode == 103 || mode == 104 || 
               mode == 203 || mode == 204) {
      buffer = calloc(1201,2);
    }
    if (SvIOK(qualifier) || looks_like_number(qualifier)) {
      qual_short = SvIV(qualifier);
      dbinfo(SvPV_nolen(basehandle),&qual_short,&mode,status,buffer);
    } else {
      dbinfo(SvPV_nolen(basehandle),SvPV_nolen(qualifier),&mode,status,buffer);
    }
    setstatus(status);
    if (status[0] != 0) {
      /* Something went wrong, don't parse return values */
      free(buffer);
      return(&PL_sv_undef);
    }
    if (mode == 101 || 
        mode == 201 || mode == 206 ||
        mode == 501 || 
        mode == 901) {
      return_sv = newSViv(*buffer);
    } else if (mode == 302) {
      new_array = newAV();

      av_push(new_array,newSViv(buffer[0]));
      av_push(new_array,newSViv(buffer[1]));
      
      return_sv = newRV_noinc((SV *)new_array);
    } else if (mode == 102 || 
               mode == 202 || mode == 205) {
      new_hash = newHV();

      char_ptr = (char *)buffer + 16;
      while (char_ptr >= (char *)buffer && *(--char_ptr) == ' ') {}
      temp_sv = newSVpvn((char *)buffer,char_ptr - (char *)buffer + 1);
      hv_store(new_hash,"name",4,temp_sv,0);

      temp_sv = newSVpvn((char *)&buffer[8],1);
      hv_store(new_hash,"type",4,temp_sv,0);

      hv_store(new_hash,"length",6,newSViv(buffer[9]),0);

      if (mode == 102) {
        hv_store(new_hash,"count",      5,newSViv(buffer[10]),         0);
      } else {
        hv_store(new_hash,"block fact",10,newSViv(buffer[10]),         0);
        hv_store(new_hash,"entries",    7,newSViv(make_int(buffer,13)),0);
        hv_store(new_hash,"capacity",   8,newSViv(make_int(buffer,15)),0);
      
        if (mode == 205) {
          hv_store(new_hash,"hwm",         3,newSViv(make_int(buffer,17)),0);
          hv_store(new_hash,"max cap",     7,newSViv(make_int(buffer,19)),0);
          hv_store(new_hash,"init cap",    8,newSViv(make_int(buffer,21)),0);
          hv_store(new_hash,"increment",   9,newSViv(make_int(buffer,23)),0);
          hv_store(new_hash,"inc percent",11,newSViv(buffer[25]),         0);
          hv_store(new_hash,"dynamic cap",11,newSViv(buffer[26]),         0);
        }
      } 

      return_sv = newRV_noinc((SV *)new_hash);
    } else if (mode == 406) {
      new_hash = newHV();

      char_ptr = (char *)buffer + 28;
      while (char_ptr >= (char *)buffer && *(--char_ptr) == ' ') {}
      temp_sv = newSVpvn((char *)buffer,char_ptr - (char *)buffer + 1);
      hv_store(new_hash,"name",4,temp_sv,0);

      hv_store(new_hash,"mode",4,newSViv(buffer[14]),0);
      hv_store(new_hash,"version",7,newSVpvn((char *)&buffer[15],2),0);

      return_sv = newRV_noinc((SV *)new_hash);
    } else if (mode == 301) {
      new_array = newAV();

      for (cnt = 1; cnt <= buffer[0]; cnt++) {
        new_hash = newHV();
        hv_store(new_hash,"set",3,newSViv(buffer[cnt*3-2]),0);
        hv_store(new_hash,"search",6,newSViv(buffer[cnt*3-1]),0);
        hv_store(new_hash,"sort",4,newSViv(buffer[cnt*3]),0);
        av_push(new_array,newRV_noinc((SV *)new_hash));
      }

      return_sv = newRV_noinc((SV *)new_array);
    } else if (mode == 103 || mode == 104 || 
               mode == 203 || mode == 204) {
      new_array = newAV();

      for (cnt = 1; cnt <= buffer[0]; cnt++) {
        av_push(new_array,newSViv(buffer[cnt]));
      }
      return_sv = newRV_noinc((SV *)new_array);
    }
    free(buffer);
    return(return_sv);
  } /* _dbinfo */

  SV *_dbopen(char *basename, char *password, short mode) {
    short status[10];
    SV *base_name;
    SV *base_handle;
    HV *base_opened;

    base_name = newSVpv(basename,0);
    if (base_name == NULL) {
      croak("Unable to newSVpv base_name for %s",basename);
    }
    dbopen(basename,password,&mode,status);
    setstatus(status);
    base_opened = newHV();
    if (base_opened == NULL) {
      croak("Unable to newHV during _dbopen of %s\n",SvPV_nolen(base_name));
    }
    hv_store(base_opened,"name",4,base_name,0);
    if (status[0] == 0) { /* Successful open */
      base_handle = newSVpvn(basename,SvCUR(base_name));
      if (base_name == NULL) {
        croak("Unable to newSVpvn base_handle for %s",SvPV_nolen(base_name));
      }
      hv_store(base_opened,"handle",6,base_handle,0);
    }
    return newRV_noinc((SV*) base_opened);
  } /* _dbopen */

  #define DBBEGIN  1
  #define DBEND    2
  #define DBMEMO   3
  #define DBXBEGIN 4
  #define DBXEND   5
  #define DBXUNDO  6

  SV *_doBUE(SV *base_s, short mode, char *text, int call) {
    short   status[10];
    int     cnt;
    short  *db_array = NULL;
    SV    **entry;
    SV    **handle;
    short   textlen;

    textlen = -strlen(text);
    if (sv_isobject(base_s) && sv_derived_from(base_s, "MPE::IMAGE")) {
      handle = hv_fetch((HV *)SvRV(*entry),"handle",6,FALSE);
      if (handle == NULL) {
        croak("DbXBegin called with invalid database handle");
      }
      switch (call) {
        case DBBEGIN: 
          dbbegin(SvPV_nolen(*handle),text,&mode,status,&textlen); 
          break;
        case DBEND:
          dbend(SvPV_nolen(*handle),text,&mode,status,&textlen); 
          break;
        case DBMEMO:
          dbmemo(SvPV_nolen(*handle),text,&mode,status,&textlen);
          break;
        case DBXBEGIN:
          dbxbegin(SvPV_nolen(*handle),text,&mode,status,&textlen); 
          break;
        case DBXEND:
          dbxend(SvPV_nolen(*handle),text,&mode,status,&textlen); 
          break;
        case DBXUNDO:
          dbxundo(SvPV_nolen(*handle),text,&mode,status,&textlen); 
          break;
      }
      return(newSVpvn(SvPV_nolen(*handle),SvCUR(*handle)));
    } else if (sv_derived_from(base_s, "ARRAY")) {
      db_array = calloc(av_len((AV *)SvRV(base_s))+4,2);
      db_array[0] = db_array[1] = 0;
      db_array[2] = av_len((AV *)SvRV(base_s))+1;
      for (cnt = 0; cnt < db_array[2]-1; cnt++) {
        entry = av_fetch((AV *)SvRV(base_s),cnt,FALSE);
        if (entry == NULL) {
          croak("Unable to av_fetch array entry %d in DbXBegin",cnt);
        }
        handle = hv_fetch((HV *)SvRV(*entry),"handle",6,FALSE);
        if (handle == NULL) {
          croak("Array element %d was not a database pointer in DbXBegin",cnt);
        }
        db_array[3+cnt] = *(short *)SvPV_nolen(*handle);
      }
      switch (call) {
        case DBBEGIN:
          dbbegin(db_array,text,&mode,status,&textlen);
          break;
        case DBEND:
          dbend(db_array,text,&mode,status,&textlen);
          break;
        case DBMEMO:
          dbmemo(db_array,text,&mode,status,&textlen);
          break;
        case DBXBEGIN:
          dbxbegin(db_array,text,&mode,status,&textlen);
          break;
        case DBXEND:
          dbxend(db_array,text,&mode,status,&textlen);
          break;
        case DBXUNDO:
          dbxundo(db_array,text,&mode,status,&textlen);
          break;
      }
      return(newSVpvn((char *)db_array,(av_len((AV *)SvRV(base_s))+4)*2));
    } else { 
      if (call == DBBEGIN || call == DBXBEGIN) {
        /* so that the programmer can call DbBegin or DbXBegin */
        /* with an array once and thereafter use the value it returned */
        strncpy(SvPV_nolen(base_s),"\0\0\0\0",4);
      }
      switch (call) {
        case DBBEGIN:
          dbbegin(SvPV_nolen(base_s),text,&mode,status,&textlen);
          break;
        case DBEND:
          dbend(SvPV_nolen(base_s),text,&mode,status,&textlen);
          break;
        case DBMEMO:
          dbmemo(SvPV_nolen(base_s),text,&mode,status,&textlen);
          break;
        case DBXBEGIN:
          dbxbegin(SvPV_nolen(base_s),text,&mode,status,&textlen);
          break;
        case DBXEND:
          dbxend(SvPV_nolen(base_s),text,&mode,status,&textlen);
          break;
        case DBXUNDO:
          dbxundo(SvPV_nolen(base_s),text,&mode,status,&textlen);
          break;
      }
      return(base_s);
    }
    setstatus(status);
  } /* _doBUE */

  /* These two work with the reals in packed form */
  SV *_IEEE_real_to_HP_real(SV *source) {
    float    sreal;
    double   lreal;
    int      status;
    short    except;

    if (SvCUR(source) == 4) {  /* 32-bit form */
      HPFPCONVERT(7,SvPV_nolen(source),&sreal,3,1,&status,&except,0);
      return(newSVpvn((char *)&sreal,4));
    } else {
      HPFPCONVERT(7,SvPV_nolen(source),&lreal,4,2,&status,&except,0);
      return(newSVpvn((char *)&lreal,8));
    }
  }

  SV *_HP_real_to_IEEE_real(SV *source) {
    float    sreal;
    double   lreal;
    int      status = 0;
    short    except = 0;

    if (SvCUR(source) == 4) {  /* 32-bit form */
      HPFPCONVERT(7,SvPV_nolen(source),&sreal,1,3,&status,&except,0);
      return(newSVpvn((char *)&sreal,4));
    } else {
      HPFPCONVERT(7,SvPV_nolen(source),&lreal,2,4,&status,&except,0);
      return(newSVpvn((char *)&lreal,8));
    }
  }


MODULE = MPE::IMAGE	PACKAGE = MPE::IMAGE	

PROTOTYPES: DISABLE

void
setDbError (ErrPtr)
	SV *	ErrPtr

void
DbExplain ()

void
_dbclose (basehandle, dataset, mode)
	SV *	basehandle
	SV *	dataset
	short	mode

void
_dbfind (basehandle, dataset, mode, item, argument)
         SV *    basehandle
         SV *    dataset
         short   mode
         SV *    item
         SV *    argument

SV *
_dbget (basehandle, dataset, mode, list, argument, size)
	SV *	basehandle
	SV *	dataset
	short	mode
	SV *	list
	SV *	argument
	int	size

SV *
_dbinfo (basehandle, qualifier, mode)
	SV *	basehandle
	SV *	qualifier
	short	mode

SV *
_dbopen (basename, password, mode)
	char *	basename
	char *	password
	short	mode

void
DbBegin (base_s, mode, text = "")
	SV *    base_s
	short   mode
        char *  text
  CODE:
    _doBUE(base_s, mode, text, DBBEGIN);

void
DbEnd (base_s, mode, text = "")
	SV *    base_s
	short   mode
        char *  text
  CODE:
    _doBUE(base_s, mode, text, DBEND);

void
DbMemo (base_s, mode, text = "")
        SV *    base_s
        short   mode
        char *  text
  CODE:
    _doBUE(base_s, mode, text, DBMEMO);

void
DbXBegin (base_s, mode, text = "")
	SV *    base_s
	short   mode
        char *  text
  CODE:
    _doBUE(base_s, mode, text, DBXBEGIN);

void
DbXEnd (base_s, mode, text = "")
	SV *    base_s
	short   mode
        char *  text
  CODE:
    _doBUE(base_s, mode, text, DBXEND);

void
DbXUndo (base_s, mode, text = "")
	SV *    base_s
	short   mode
        char *  text
  CODE:
    _doBUE(base_s, mode, text, DBXUNDO);

SV *
_IEEE_real_to_HP_real (source)
	SV *	source

SV *
_HP_real_to_IEEE_real (source)
	SV *	source

