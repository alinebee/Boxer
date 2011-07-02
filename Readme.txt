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

XCode 4 does not come with PowerPC compilers out-of-the-box, which will normally prevent you from building the Release configuration. However, you can install XCode 3.2.x alongside XCode 4: this comes with the necessary PowerPC build tools, and will make them available for XCode 4 to use also.

It Worked For Me to just install 3.2 alongside XCode 4, with only the essentials and leaving out all other components. However, you may have to jump through some extra hoops: q.v. http://stackoverflow.com/questions/5333490/how-can-we-restore-ppc-ppc64-as-well-as-full-10-4-10-5-sdk-support-to-xcode-4

Some of Boxer's XIB files cannot be opened for editing in XCode 4, because they rely on an Interface Builder 3 plugin. To edit these XIBs, you must open them in the Interface Builder from XCode 3.2.x instead.


Having trouble?
---------------
If you have any problems building the Boxer project, or questions about Boxer's code, please get in touch with me at abestor@boxerapp.com and I'll help out as best I can.

