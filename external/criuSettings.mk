##############################################################################
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
##############################################################################

# - is shell metacharacter. In PLATFORM value, replace - with _
export CRIU_COMBO_LIST_x86_64_linux=sw.os.ubuntu.22-hw.arch.x86.broadwell sw.os.ubuntu.22-hw.arch.x86.amd sw.os.rhel.8-hw.arch.x86.broadwell sw.os.rhel.8-hw.arch.x86.amd sw.os.rhel.8-hw.arch.x86.skylake sw.os.rhel.9-hw.arch.x86.amd sw.os.rhel.9-hw.arch.x86.skylake
# not available: sw.os.ubuntu.22-hw.arch.x86.skylake sw.os.rhel.9-hw.arch.x86.broadwell

export CRIU_COMBO_LIST_linux_390_64_z13=sw.os.ubuntu.22-hw.arch.s390x.z13
# not available: sw.os.rhel.8-hw.arch.s390x.z13
export CRIU_COMBO_LIST_linux_390_64_z14=sw.os.ubuntu.22-hw.arch.s390x.z14 sw.os.rhel.8-hw.arch.s390x.z14 sw.os.rhel.9-hw.arch.s390x.z14
export CRIU_COMBO_LIST_linux_390_64_z15=sw.os.ubuntu.22-hw.arch.s390x.z15 sw.os.rhel.8-hw.arch.s390x.z15 sw.os.rhel.9-hw.arch.s390x.z15

export CRIU_COMBO_LIST_aarch64_linux=sw.os.ubuntu.22-hw.arch.aarch64.armv8 sw.os.rhel.9-hw.arch.aarch64.armv8
# not available: sw.os.rhel.8-hw.arch.aarch64.armv8 sw.os.ubuntu.20-hw.arch.aarch64.armv8

# placeholder 
export CRIU_COMBO_LIST_ppc64le_linux=
