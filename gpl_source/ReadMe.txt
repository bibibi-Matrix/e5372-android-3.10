    This text is about how to compile the softwares in the package. You need to pay attention to your build environment, and do as this document to compile the softwares.

===================
1. Environmental Requirements
    1) OS: Linux Distributions, better Unbuntu.
        For example:
            Distributor ID: Ubuntu
            Description: Ubuntu 12.04.4 LTS
            Release: 12.04
            Codename: precise

    2) Compiler
        Sourcery_G++_Lite 4.5.1
      After you have install the toolchains, modify the Makefile in E5372:
        TOOLCHAIN_TOP = /opt/CodeSourcery/Sourcery_G++_Lite
        change the path to your own path of Sourcery_G++_Lite.
      Notice: gcc for X86/64 maybe can not work. 


2. build source
    $cd source/
    $make all
  if you want to build one software (eg. iptables),
    $make iptables
  you can find target file in the source code folder.

Notice: Please keep the target folder, otherwise it will not work.
If you can compile the software in android firmware build environment, you should be able to more easily compile.

3. build android
    $cd android-2.6.35
    $build.sh

