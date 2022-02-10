from unittest import TestCase

from generateDisabledTestListJson import transform_platform

platform_map = {
    "linux-aarch64": "aarch64_linux",
    "linux-ppc64le": "ppc64le_linux",
    "linux-arm": "arm_linux",
    "linux-s390x": "s390x_linux",
    "linux-x64": "x86-64_linux",
    "macosx-x64": "x86-64_mac",
    "windows-x64": "x86-64_windows",
    "windows-x86": "x86-32_windows",
    "z/OS-s390x": "s390x_zos",
    "linux-ppc32": "ppc32_linux",
    "linux-ppc64": "ppc64_linux",
    "linux-riscv64": "riscv64_linux",
    "linux-s390": "s390_linux",
    "solaris-sparcv9": "sparcv9_solaris",
    "solaris-x86-64": "x86-64_solaris",
    "alpine-linux-x86-64": "x86-64_alpine-linux",
    "linux-x86-32": "x86-32_linux",

    "linux-all": "all_linux",
    "macosx-all": "all_mac",
}


class Test(TestCase):
    def test_transform_platform_with_map(self):
        for k, v in platform_map.items():
            self.assertEqual(transform_platform(k), v)
