Some notes on building Boxer
============================

Thanks for downloading the Boxer XCode project! This project is designed to be a painless one-click build, but there are a few caveats explained below, so please read this before you get to work.


Requirements
------------

To build the Boxer project you will need OS X 10.6 or higher and XCode 3.2 or higher. (See below for notes about XCode 4 compatibility.)

All required frameworks are included in the Boxer project, so the project itself is all you need.


Build Configurations
--------------------

The Boxer project has 2 build configurations: Release and Debug.
- Release compiles an optimized 32-bit universal binary for PowerPC and Intel i386.
- Debug compiles an optimized binary in your current system architecture only, and turns on console debug messages.

Both have pretty much identical emulation performance. Until you want to distribute your build to others, you'll want to stick with Debug for faster build times, since a Universal binary takes twice as long to build.


XCode 4 Caveats
---------------

XCode versions 4.0 and later do not come with PowerPC compilers, which will normally prevent you from building the Release configuration. However: if you are still using OS X 10.6, then you can install XCode 3.2.x alongside XCode 4.x and compile the Release configuration using that. (Note that XCode 3.2 apparently cannot be used on Lion.)


Having trouble?
---------------
If you have any problems building the Boxer project, or questions about Boxer's code, please get in touch with me at abestor@boxerapp.com and I'll help out as best I can.

