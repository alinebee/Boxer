/* 
 Boxer is copyright 2012 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXAppKitVersionHelpers.h"


BOOL isRunningOnLeopard()
{
	double appKitVersion = floor(NSAppKitVersionNumber);
	return (appKitVersion <= NSAppKitVersionNumber10_5);	
}

BOOL isRunningOnSnowLeopard()
{
	double appKitVersion = floor(NSAppKitVersionNumber);
	return (appKitVersion <= NSAppKitVersionNumber10_6 && appKitVersion > NSAppKitVersionNumber10_5);	
}

BOOL isRunningOnLion()
{
	double appKitVersion = floor(NSAppKitVersionNumber);
	return (appKitVersion <= NSAppKitVersionNumber10_7 && appKitVersion > NSAppKitVersionNumber10_6);
}

BOOL isRunningOnSnowLeopardOrAbove()
{
	double appKitVersion = floor(NSAppKitVersionNumber);
	return (appKitVersion > NSAppKitVersionNumber10_5);
}

BOOL isRunningOnLionOrAbove()
{
	double appKitVersion = floor(NSAppKitVersionNumber);
	return (appKitVersion > NSAppKitVersionNumber10_6);
}