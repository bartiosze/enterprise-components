/L/ Copyright (c) 2011-2014 Exxeleron GmbH
/L/
/L/ Licensed under the Apache License, Version 2.0 (the "License");
/L/ you may not use this file except in compliance with the License.
/L/ You may obtain a copy of the License at
/L/
/L/   http://www.apache.org/licenses/LICENSE-2.0
/L/
/L/ Unless required by applicable law or agreed to in writing, software
/L/ distributed under the License is distributed on an "AS IS" BASIS,
/L/ WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
/L/ See the License for the specific language governing permissions and
/L/ limitations under the License.

/V/ 3.0

/S/ Refresh permissions component:
/S/ Responsible for:
/S/ - regeneration of user access files (used with -u/-U options)
/S/.
/S/ Notes:
/S/ - this script generates one file for each component with permitted users information taken from access.cfg file.
/S/ - files are generated in cfg.userTxtPath specified directory.

/T/ yak start refreshPerm

/------------------------------------------------------------------------------/
/                               lib and etc                                    /
/------------------------------------------------------------------------------/
system"l ",getenv[`EC_QSL_PATH],"/sl.q";
.sl.init[`refUFiles];
.sl.lib["cfgRdr/cfgRdr"];

/------------------------------------------------------------------------------/

/F/ Initialization function
.sl.main:{
  .cr.loadCfg[`ALL];
  .ru.p.init[];
  exit[0];
  };

.ru.p.init:{[params]
  // define users
  .log.info[`ru] "Refreshing user access files...";
  dx:{[x;y] `char$0b sv/:y<>/:0b vs/:`int$x}[;.sl.p.m];
  groups:select groupname:sectionVal, procname:subsection from .cr.getCfgTab[`ALL; `userGroup;`namespaces];
  groupsn:(ungroup update procname:count[g]#enlist .cr.p.procNames except `ALL from g:select from groups where procname=`ALL),select from groups where procname<>`ALL;
  users:ungroup select user:sectionVal,pass:(count'[usergroups])#'enlist each value each pass, usergroups from .cr.getGroupCfgPivot[`user`technicalUser;`pass`usergroups];
  matched:distinct delete usergroups from ungroup (`usergroups xcol groupsn) lj `usergroups xgroup users;
  umatched: matched lj `procname xcol select from .cr.getByProc[enlist `uFile] where not uFile=`$":";
  / fetch only non-empty configurations
  umatched: delete from umatched where null uFile;
  .ru.p.verify[umatched];
  d: exec flip `user`pass!(user;""sv/:string md5 each dx each pass) by uFile from umatched;
  .ru.p.genUfiles'[key d;value d];
  .log.info[`ru] "Refresh completed";
  };

/------------------------------------------------------------------------------/
.ru.p.genUfiles:{[path;u]
 users:distinct u;
 .log.info[`ru]"Create security file in ",string[path]," with #users:",string count users;
 path 0:1_":" 0:users;
 };

.ru.p.verify:{[umatched]
  / check user count per process vs count per distinct u file
  perproc:select pucnt:count i by procname, uFile  from umatched;
  perfile:select fucnt:count distinct user  by uFile from umatched;
  /find not equal counts in files
  faultyFiles:exec distinct uFile from (perproc lj perfile) where pucnt<>fucnt;
  /find processes providing more users
  faultyProcs:exec procname!uFile from (perproc lj perfile) where uFile in faultyFiles,pucnt=fucnt;
  .log.warn[`ru] "Some processes (", (", " sv string key faultyProcs), ") provide additional users to a \"shared\" user files ", 
                   "(", (", " sv string value faultyProcs), ").";
  .log.warn[`ru] "Please provide separate user files for those processes.";
  }

/------------------------------------------------------------------------------/
.sl.run[`ru;`.sl.main;`];

/==============================================================================/
