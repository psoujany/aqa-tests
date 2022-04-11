#!/usr/bin/perl
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

use Test::Simple tests => 3;
use File::Path;
use File::Compare;
use FindBin;

$OS=$^O; #OS name
chomp($OS);
$SYSENC=`locale charmap`;
chomp($SYSENC);
$lang = $ENV{LANG};
$i = index($lang,".");
if ($i == -1) {
    $i = length($lang);
}
$lang = substr($lang, 0, $i);
$FULLLANG = $OS."_".$lang.".".$SYSENC;
undef %LOC;
foreach $l (
    "aix_Ja_JP.IBM-943","aix_ja_JP.IBM-eucJP","aix_JA_JP.UTF-8",
    "aix_ko_KR.IBM-eucKR","aix_KO_KR.UTF-8",
    "aix_zh_CN.IBM-eucCN","aix_Zh_CN.GB18030","aix_ZH_CN.UTF-8",
    "aix_zh_TW.IBM-eucTW","aix_Zh_TW.big5","aix_ZH_TW.UTF-8",
    "darwin_ja_JP.UTF-8", "darwin_ko_KR.UTF-8", "darwin_zh_CN.UTF-8", "darwin_zh_TW.UTF-8",
    "linux_ja_JP.UTF-8","linux_ko_KR.UTF-8","linux_zh_CN.UTF-8","linux_zh_TW.UTF-8")
{
    $LOC{$l} = "";
}
foreach $l (
    "aix_ja_JP.UTF-8","aix_ko_KR.UTF-8", "aix_zh_Hans_CN.UTF-8", "aix_zh_Hant_TW.UTF-8")
{
    $LOC{$l} = ".s";
}

if (defined($LOC{$FULLLANG})) {
    $FULLLANG .= $LOC{$FULLLANG};
} else {
    for($i = 0; $i < 3; $i+=1) {
        ok(1 == 1,"skip");
    }
    print "SKIPPED! $FULLLANG is not supported.\n";
    exit(0);
}

unless (defined($ENV{'JAVA_BIN'})) {
    if (-f $ENV{'TEST_JDK_HOME'}."/jre/bin/java"){
        $ENV{'JAVA_BIN'} = $ENV{'TEST_JDK_HOME'}."/jre/bin"
    }else{
        $ENV{'JAVA_BIN'} = $ENV{'TEST_JDK_HOME'}."/bin"
    }
}

#print $lang."\n";
#print $OS."\n";
#print $SYSENC."\n";
print "# ".$FULLLANG."\n";

rmtree("./result");
mkdir("result");

$base = $FindBin::Bin."/";
print "base ".$base."\n";
$jar = "-cp ".$base."i18n.jar";

open(CMD, "$ENV{'JAVA_BIN'}/java -XshowSettings:properties -version 2>&1 |");
while(<CMD>) {
  $rc = $1 if /^\s+java\.version = (\d+)/;
}
$rc = 8 if $rc == 1;
if ($rc lt 18) {
  system($ENV{'JAVA_BIN'}."/java ".$jar." showlocale > result/showlocale.out");
  system($ENV{'JAVA_BIN'}."/java ".$jar." DateFormatTest > result/DateFormatTest.out");
  system($ENV{'JAVA_BIN'}."/java ".$jar." BreakIteratorTest ".$base.$FULLLANG.".txt > result/BreakIteratorTest.out");
} else {
  system($ENV{'JAVA_BIN'}."/java -Dfile.encoding=COMPAT ".$jar." showlocale > result/showlocale.out");
  system($ENV{'JAVA_BIN'}."/java -Dfile.encoding=COMPAT ".$jar." DateFormatTest > result/DateFormatTest.out");
  system($ENV{'JAVA_BIN'}."/java -Dfile.encoding=COMPAT ".$jar." BreakIteratorTest ".$base.$FULLLANG.".txt > result/BreakIteratorTest.out");
}

#
# checking the results
#
ok( compare("result/showlocale.out", 
            $base."expected/".$FULLLANG."/showlocale.out") == 0,
    "showlocale test");
ok( compare("result/BreakIteratorTest.out",
            $base."expected/".$FULLLANG."/BreakIteratorTest.out") == 0,
    "BreakIteratorTest test");

open(DATA, "< result/DateFormatTest.out");
$flag = 0;
while (my $line = <DATA>) {
    chomp($line);
    if ($line eq "OK") {
        $flag=1;
    }
}
close(DATA);
ok( $flag == 1, "DateFormatTest");
