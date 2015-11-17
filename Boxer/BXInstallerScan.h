/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXInstallerScan is used by BXImportSession for locating DOS game installers within a path
//or volume. It populates its matchingPaths with all the DOS installers it finds, ordered
//by relevance - with the preferred installer first. 

//It also collects overall file data about the source while scanning, such as the game profile
//and whether the game appears to be already installed (or not a DOS game at all).

#import "ADBImageAwareFileScan.h"

@class BXGameProfile;
@interface BXInstallerScan : ADBImageAwareFileScan
{
    NSMutableArray<NSString*> *_windowsExecutables;
    NSMutableArray<NSString*> *_DOSExecutables;
    NSMutableArray<NSString*> *_macOSApps;
    NSMutableArray<NSString*> *_DOSBoxConfigurations;
    BOOL _alreadyInstalled;
    
    BXGameProfile *_detectedProfile;
} 

//The relative paths of all DOS and Windows executables and DOSBox configuration files
//discovered during scanning.
@property (readonly, retain, nonatomic) NSArray<NSString*> *windowsExecutables;
@property (readonly, retain, nonatomic) NSArray<NSString*> *DOSExecutables;
@property (readonly, retain, nonatomic) NSArray<NSString*> *macOSApps;
@property (readonly, retain, nonatomic) NSArray<NSString*> *DOSBoxConfigurations;

//The path which the scanner recommends as the base path to import from.
//This will usually be the same as the base path, but may point to a mounted
//volume instead if the base path was an image.
@property (readonly, copy, nonatomic) NSString *recommendedSourcePath;

//The profile of the game at the base path, used for discovery of additional installers.
//If left unspecified, this will be autodetected during scanning.
@property (readonly, retain, nonatomic) BXGameProfile *detectedProfile;

//Whether the game at the base path appears to be already installed.
@property (readonly, nonatomic, getter=isAlreadyInstalled) BOOL alreadyInstalled;

@end
