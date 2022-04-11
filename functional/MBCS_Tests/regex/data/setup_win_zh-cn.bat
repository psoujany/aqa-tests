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

@echo ------------ Pattern matching test ------------

java %JAVA_OPTIONS% SimpleGrep �V�W�X�Y�Z�[�\�]�@�A�B�C %PWD%\win_zh-cn.txt
@echo --- Confirm that the line(s) includes "�V�W�X�Y�Z�[�\�]�@�A�B�C". 
@echo --- Did you get the line(s)?

java %JAVA_OPTIONS% SimpleGrep "�V*�X" %PWD%\win_zh-cn.txt
@echo --- Confirm that the line(s) includes the pattern "�V*�X". 
@echo --- Did you get the line(s) ?

java %JAVA_OPTIONS% SimpleGrep "^��" %PWD%\win_zh-cn.txt
@echo --- Confirm that the line(s) starts with "��".
@echo --- Did you get the line ?

java %JAVA_OPTIONS% SimpleGrep �� %PWD%\win_zh-cn.txt
@echo --- Confirm that the line(s) includes "��". 
@echo --- Did you get the line ?

java %JAVA_OPTIONS% SimpleGrep �� %PWD%\win_zh-cn.txt
@echo --- Confirm that the line(s) includes "��". 
@echo --- Did you get the line?

java %JAVA_OPTIONS% SimpleGrep \u628e\u99e1U\u90c2 %PWD%\win_zh-cn.txt
@echo --- Confirm that the line(s) includes "��d���". 
@echo --- Did you get the line ?


@echo\
@echo ------------ Pattern replacement test ------------

java %JAVA_OPTIONS% RegexReplaceTest �V�W�X�Y�Z�[�\�]�@�A�B�C aiueo %PWD%\win_zh-cn.txt -v
@echo --- Confirm that "�V�W�X�Y�Z�[�\�]�@�A�B�C" was replaced by "aiueo". 
@echo --- OK ?

java %JAVA_OPTIONS% RegexReplaceTest �� �J�^�J�i %PWD%\win_zh-cn.txt -v
@echo --- Confirm that "��" was replaced by "�J�^�J�i". 
@echo --- OK ?

java %JAVA_OPTIONS% RegexReplaceTest �� \\ %PWD%\win_zh-cn.txt -v
@echo --- Confirm that "��" was replaced by "\". 
@echo --- OK ?

java %JAVA_OPTIONS% RegexReplaceTest \u628e\u99e1U\u90c2 �߇� %PWD%\win_zh-cn.txt -v
@echo --- Confirm that "��d���" was replaced by "�߇�". 
@echo --- OK ?

