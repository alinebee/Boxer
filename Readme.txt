Some notes on building Boxer
============================

Thanks for downloading the Boxer XCode project! This project is designed to be a painless one-click build, but there are a few caveats explained below, so please read this before you get to work.


Requirements
------------

To build the Boxer project you will need XCode 3.x. XCode 4 is not supported yet, as it does not include the OS X 10.5 SDK and doesn't ship with GCC 4.0, upon both of which Boxer currently relies.

All required frameworks are included in the Boxer project itself, so the project itself is all you need.


Build Configurations
--------------------

The Boxer project has 3 build configurations: Debug, Development and Release. 
- Debug is the standard XCode debug configuration and will give very slow emulation. (In fact, last I checked, it won’t even run. Don’t use this.)
- Release compiles an optimised 32-bit universal binary for PPC and Intel.
- Development compiles an optimised binary for the current system architecture only.

Until you want to distribute your build to others, you'll want to stick with Development for faster build times.


Building Boxer
--------------

NOTE FOR XCODE 3.1 (OS X 10.5) USERS: you must compile Boxer using the Development build configuration, otherwise you will get spurious errors during the copy phase of compilation. The Development build configuration has the "Strip debug symbols during copy" option turned off, which prevents these errors, but the option is left on for Release builds.


You will notice a large number of warnings when compilation gets to DOSBox's source files. The Boxer project has all feasible GCC warning options turned on to highlight potential bugs in Boxer's code; unfortunately, these options also highlight hundreds of potential bugs in DOSBox's code, none of which are likely to be fixed any time soon.


Having trouble?
---------------
If you have any problems building the Boxer project, or questions about Boxer's code, please get in touch with me at abestor@boxerapp.com and I'll help out as best I can.

