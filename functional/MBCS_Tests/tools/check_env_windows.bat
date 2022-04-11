@echo off
rem Licensed under the Apache License, Version 2.0 (the "License");
rem you may not use this file except in compliance with the License.
rem You may obtain a copy of the License at
rem
rem      https://www.apache.org/licenses/LICENSE-2.0
rem
rem Unless required by applicable law or agreed to in writing, software
rem distributed under the License is distributed on an "AS IS" BASIS,
rem WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
rem See the License for the specific language governing permissions and
rem limitations under the License.

if defined TEST_JDK_HOME (
   if exist %TEST_JDK_HOME%/jre/bin/java.exe (
      SET JAVA_BIN=%TEST_JDK_HOME%/jre/bin
   ) else (
      SET JAVA_BIN=%TEST_JDK_HOME%/bin
   )
)

set JAVA_VER=8
FOR /F "usebackq tokens=1,3" %%i IN (`%JAVA_BIN%\java -XshowSettings:properties -version 2^>^&1`) DO (
   if java.version==%%i set JAVA_VER=%%j
)
set JAVA_VER=%JAVA_VER:~0,2%
if 1.==%JAVA_VER% set JAVA_VER=8

if %JAVA_VER% GEQ 18 (
   SET JAVA_OPTIONS=-Dfile.encoding=COMPAT
   SET JAVAC_OPTIONS=-J-Dfile.encoding=COMPAT
) else (
   SET JAVA_OPTIONS=
   SET JAVAC_OPTIONS=
)

FOR /F "usebackq" %%i IN (`cscript //NOLOGO %PWD%\locale.vbs`) DO SET LOCALE=%%i
SET STATUS=UKNOWN
echo %CD% | findstr "jaxp14" > NUL
set JAXP14=%ERRORLEVEL%
if %LOCALE% == ja (
   SET STATUS=OK
   if %JAXP14% == 0 (
      SET XMLFILE=drinks_%LOCALE%-jp.xml
      SET XSLFILE=drinks_%LOCALE%-jp.xsl
      SET EXPECTEDFILE=win_%LOCALE%.html
   )
)
if %LOCALE% == ko (
   SET STATUS=OK
   if %JAXP14% == 0 (
      SET XMLFILE=drinks_%LOCALE%-kr.xml
      SET XSLFILE=drinks_%LOCALE%-kr.xsl
      SET EXPECTEDFILE=win_%LOCALE%.html
   )
)
if %LOCALE% == zh-cn (
   SET STATUS=OK
   if %JAXP14% == 0 (
      SET XMLFILE=drinks_%LOCALE%.xml
      SET XSLFILE=drinks_%LOCALE%.xsl
      SET EXPECTEDFILE=win_%LOCALE%.html
   )
)
if %LOCALE% == zh-tw (
   SET STATUS=OK
   if %JAXP14% == 0 (
      SET XMLFILE=drinks_%LOCALE%.xml
      SET XSLFILE=drinks_%LOCALE%.xsl
      SET EXPECTEDFILE=win_%LOCALE%.html
   )
)
if not %STATUS% == OK (
    echo SKIPPED!  This testcase is designed for Japanese, Korean, Chinese or Taiwan Windows environment. 
    exit 0
)
