Some notes on building Boxer
============================

The Boxer XCode project is designed to be a painless one-click build. Here's a quick rundown of how it's set up:

Requirements
------------

To build the Boxer project you will need OS X 10.7 or higher and XCode 4.3 or higher.
All necessary frameworks are included in the Boxer project, so the project itself is all you need.

Build Targets
-------------

The Boxer project has two targets: "Boxer" and "Standalone Boxer". "Boxer" is the standard emulator you know and love. "Standalone Boxer" is a cut-down version of Boxer meant for wrapping up existing gameboxes into a single unified app. Game importing and settings UI have been stripped out of this version and it will only launch the gamebox that you bundle inside it (which you currently have to do manually).

Build Configurations
--------------------

The Boxer project has 2 build configurations: Release and Debug. Both of them compile fully optimized 32-bit binaries using the LLVM compiler. Debug works almost exactly the same as Release but turns on console debug messages and additional OpenGL error-checking.

Boxer currently does not compile for 64-bit because DOSBox is not fully 64-bit compatible. Boxer's bundled frameworks have also been stripped down to 32-bit-only to save space.

Having trouble?
---------------
If you have any problems building the Boxer project, or questions about Boxer's code, please get in touch with me at abestor@boxerapp.com and I'll help out as best I can.

