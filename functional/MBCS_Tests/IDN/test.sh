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
OS=`uname`
LOC=`locale charmap`
FULLLANG=${OS}_${LANG%.*}.${LOC}

BASE=`dirname $0`
export CLASSPATH=${BASE}/IDN.jar
OUTPUT=output.txt
. ${BASE}/check_env_unix.sh
CHARMAP=${FULLLANG}
SOURCE="${CHARMAP}.txt"

LISTS=`ls ${BASE}/${FULLLANG}*.txt`
rm -f ${OUTPUT}
echo "launching IDNFromFile..."
for i in ${LISTS}
do
        j=${i##/*/}
	echo
	echo ${j}
	${JAVA_BIN}/java ${JAVA_OPTIONS} IDNFromFile $i
        RESULT=$?
	if [ ${RESULT} != 0 ]; then 
            exit ${RESULT}
        fi
	mv toAscii.txt ${i}_toAscii
        cat ${i}_toAscii >> ${OUTPUT}

	echo "Comparing ${j}_toAscii with ${j}_toascii"

	mv toUnicode.txt ${i}_toUnicode
        cat ${i}_toUnicode >> ${OUTPUT}

	echo "Comparing ${j}_toUnicode with ${j}_tounicode"
done

. ${BASE}/setup_${FULLLANG}
echo "URL=http://${TEST_HOSTNAME}" >> ${OUTPUT}
echo "converting URL from UNICODE to ACE..." >> ${OUTPUT}
TOASCII=`${JAVA_BIN}/java ${JAVA_OPTIONS} IDNtoASCII ${TEST_HOSTNAME}`
echo "ACE=http://${TOASCII}"  >> ${OUTPUT}
echo "converting URL from ACE to UNICODE..."  >> ${OUTPUT}
TOUNICODE=`${JAVA_BIN}/java IDNtoUNICODE ${TOASCII}`
echo "UNICODE=http://${TOUNICODE}"  >> ${OUTPUT}

diff ${BASE}/expected_${SOURCE} ${OUTPUT} > /dev/null 2>&1
RESULT=$?
exit ${RESULT}
