/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXEmulatorConfiguration is a Property List-style parser for configuration files in DOSBox format.
//It can read and write conf files, though it is not currently able to preserve layout and comments.

#import <Foundation/Foundation.h>

@interface BXEmulatorConfiguration : NSObject
{
	//Our private storage of configuration sections
	NSMutableDictionary *sections;
	
	NSString *preamble;
	NSString *startupCommandsPreamble;
}

#pragma mark -
#pragma mark Properties

//Whether the configuration has any settings or startup commands in it.
@property (readonly, nonatomic) BOOL isEmpty;

//Returns a dictionary of all settings organised by section (not including startup commands.)
@property (readonly, nonatomic) NSDictionary *settings;

//Returns an array of all startup commands.
@property (readonly, nonatomic) NSArray *startupCommands;

//A string to prepend as a header comment at the start of the configuration file.
//Used by description and writeToFile:error:
@property (copy, nonatomic) NSString *preamble;

//A string to prepend as a section comment to the start of the autoexec block.
//Used by description and writeToFile:error:
@property (copy, nonatomic) NSString *startupCommandsPreamble;


#pragma mark -
#pragma mark Loading and saving configurations

//Returns an autoreleased instance initialized with the settings in the file at the specified path.
//Will return nil and populate outError on failure to read the file.
+ (id) configurationWithContentsOfFile: (NSString *)filePath error: (NSError **)outError;

//Returns an autoreleased instance initialized with settings parsed from the specified string.
+ (id) configurationWithString: (NSString *)configuration;

//Returns an autoreleased empty configuration.
+ (id) configuration;


//Initializes with the settings in the file at the specified path.
//Will return nil and populate outError on failure to read the file.
- (id) initWithContentsOfFile: (NSString *)filePath error: (NSError **)outError;

//Initializes with settings parsed from the specified DOSBox-formatted configuration string.
- (id) initWithString: (NSString *)configuration;

//Initializes with a heirarchical dictionary of sections and settings.
- (id) initWithSettings: (NSDictionary *)initialSettings;


//Writes the configuration in DOSBox format atomically to the specified location.
//Returns YES if write was successful, or NO and sets error if the write failed.

//NOTE: this will overwrite any file that exists at that path. It will not currently
//preserve the layout or comments of the file it is replacing, nor the file from which
//the configuration was originally loaded (if any).
- (BOOL) writeToFile: (NSString *)filePath error: (NSError **)error;

//Returns a string representation of the configuration in DOSBox format,
//as it would look when written to a file.
- (NSString *) description;


#pragma mark -
#pragma mark Setting and getting individual settings

//Gets the value for the setting with the specified key under the specified section.
//Will return nil if the setting is not found.
- (NSString *) valueForKey: (NSString *)settingName
				 inSection: (NSString *)sectionName;

//Sets the value for the setting with the specified key under the specified section.
- (void) setValue: (NSString *)settingValue
		   forKey: (NSString *)settingName
		inSection: (NSString *)sectionName;

//Removes the setting with the specified key and section altogether from the configuration.
- (void) removeValueForKey: (NSString *)settingName
				 inSection: (NSString *)sectionName;


#pragma mark -
#pragma mark Setting and getting startup commands

//Adds the specified command onto the end of the startup commands.
- (void) addStartupCommand: (NSString *)command;

//Adds all the specified commands onto the end of the startup commands.
- (void) addStartupCommands: (NSArray *)commands;

//Removes all occurrences of the specified command.
//Only exact matches will be removed.
- (void) removeStartupCommand: (NSString *)command;

//Removes all startup commands.
- (void) removeStartupCommands;


#pragma mark -
#pragma mark Setting and getting sections

//Return a dictionary of all settings for the specified section.
- (NSDictionary *) settingsForSection: (NSString *)sectionName;

//Replaces the settings for the specified section with the new ones.
- (void) setSettings: (NSDictionary *)newSettings forSection: (NSString *)sectionName;

//Merges the specfied configuration settings into the specified section.
//Duplicate settings will be overridden; otherwise existing sections and settings will be left in place.
- (void) addSettings: (NSDictionary *)newSettings toSection: (NSString *)sectionName;

//Remove an entire section and all its settings.
- (void) removeSection: (NSString *)sectionName;


#pragma mark -
#pragma mark Merging settings from other configurations

//Merges the configuration settings from the specified configuration into this one.
//Duplicate settings will be overridden; otherwise existing sections and settings will be left in place.
- (void) addSettingsFromConfiguration: (BXEmulatorConfiguration *)configuration;

//Merges the configuration settings from the specified dictionary into this configuration.
//Duplicate settings will be overridden; otherwise existing sections and settings will be left in place.
- (void) addSettingsFromDictionary: (NSDictionary *)newSettings;

//Eliminates all configuration settings that are identical to those in the specified configuration,
//leaving only the settings that differ.
- (void) excludeDuplicateSettingsFromConfiguration: (BXEmulatorConfiguration *)configuration;

@end
