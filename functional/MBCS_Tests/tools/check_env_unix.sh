#!/bin/sh
################################################################################
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
################################################################################

setData() {
    . ${BASE}/../data/test_${FULLLANG}
    ${JAVA_BIN}/java -XshowSettings:properties -version 2>&1 | perl -e 'while(<>){$rc=$1 if /^\s+java\.version = (\d+)/;}$rc=8 if $rc==1;exit($rc);'
    export JAVA_VER=$?
    test ${JAVA_VER} -ge 18 && export JAVAC_OPTIONS=-J-Dfile.encoding=COMPAT && export JAVA_OPTIONS=-Dfile.encoding=COMPAT
}

showMessage() {
    echo "SKIPPED! ${FULLLANG} is not supported"
    exit 0
}

if [ "x$JAVA_BIN" = "x" ]; then
    if [ -x "${TEST_JDK_HOME}/jre/bin/java" ] ; then
        export JAVA_BIN=${TEST_JDK_HOME}/jre/bin
    else
        export JAVA_BIN=${TEST_JDK_HOME}/bin
    fi
fi

case "${FULLLANG}" in
    "AIX_Ja_JP.IBM-943"|\
    "AIX_ja_JP.IBM-eucJP"|\
    "AIX_JA_JP.UTF-8"|\
    "AIX_ko_KR.IBM-eucKR"|\
    "AIX_KO_KR.UTF-8"|\
    "AIX_zh_CN.IBM-eucCN"|\
    "AIX_Zh_CN.GB18030"|\
    "AIX_ZH_CN.UTF-8"|\
    "AIX_zh_TW.IBM-eucTW"|\
    "AIX_Zh_TW.big5"|\
    "AIX_ZH_TW.UTF-8"|\
    "Darwin_ja_JP.UTF-8"|\
    "Darwin_ko_KR.UTF-8"|\
    "Darwin_zh_CN.UTF-8"|\
    "Darwin_zh_TW.UTF-8"|\
    "Linux_ja_JP.UTF-8"|\
    "Linux_ko_KR.UTF-8"|\
    "Linux_zh_CN.UTF-8"|\
    "Linux_zh_TW.UTF-8")
        setData ;;
    "AIX_ja_JP.UTF-8"|\
    "AIX_ko_KR.UTF-8")
        FULLLANG=${FULLLANG}.s
        setData ;;
    *) showMessage ;;
esac
