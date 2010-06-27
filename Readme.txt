Some notes on building Boxer
============================

Thanks for downloading the Boxer XCode project! This project is designed to be a quick and painless one-click build, but there are a few caveats explained below, so please read this before you get to work.


Requirements
------------

To build Boxer, you will need XCode 3.1 or later and OS X 10.5 or later. All other dependencies (frameworks etc.) are included in the Boxer project itself.


Building for the first time (or: Help! Interface Builder errors when compiling!)
---------------------------

Boxer uses a third-party Interface Builder plugin included with the project; you will need to tell Interface Builder where to find this plugin before you can build Boxer, otherwise you will get errors when opening or compiling Boxer's XIB files. To do so:
1. Start up Interface Builder;
2. Go to the Preferences->Plug-ins pane and click the + button;
3. Add [Boxer project folder]/Frameworks/BGHUDAppKit.framework.

After this, Boxer's XIB files should compile without errors, and building Boxer will be a one-click process from now on. (Note that if you ever move the Boxer project, you will probably need to re-add the BGHUDAppKit framework to Interface Builder so it knows where to find it.)


Build Configurations
--------------------

The Boxer project has 3 build configurations: Debug, Development and Release. 
- Debug is the standard XCode debug configuration and will provide very slow emulation.
- Release compiles an optimised 32-bit universal binary for PPC and Intel.
- Development compiles an optimised binary for the current system architecture only.

Until you want to distribute your build to others, you'll want to stick with Development for faster build times.


Having trouble?
---------------
If you have any problems building the Boxer project, or questions about Boxer's code, please get in touch with me at abestor@boxerapp.com and I'll help out as best I can.

