/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXEmulatorConfiguration.h"
#import "BXEmulator.h" //For encodings
#import "NSString+ADBStringFormatting.h"
#import "RegexKitLite.h"


//The number of DOSBox configuration sections we know exist.
//Used only for determining initial dictionary size and has no effect on behaviour.
#define BXConfigurationNumKnownSections 13

//The initial size to use when constructing DOSBox-format string representations of a configuration.
//Used only for determining initial string size and has no effect on behaviour.
#define BXConfigurationInitialFormattedStringSize 200

//The line length to which to wrap configuration files.
#define BXConfigurationWordWrap 76


#pragma mark -
#pragma mark Regular expressions

//TODO: verify that these accurately correspond to DOSBox's parsing behaviour
//(In particular, whether DOSBox allows leading whitespace)

//Matches "[section]" with optional leading and interstitial whitespace
NSString * const BXEmulatorConfigurationSectionFormat   = @"^\\s*\\[\\s*(\\w+)\\s*\\]";

//Matches "setting=value" with optional leading and interstitial whitespace
NSString * const BXEmulatorConfigurationSettingFormat	= @"^\\s*(\\w+)\\s*=\\s*(.+)";

//Matches "#comment" with optional leading whitespace
NSString * const BXEmulatorConfigurationCommentFormat	= @"^\\s*#(.*)";

//Matches any line that is nothing but whitespace
NSString * const BXEmulatorConfigurationEmptyFormat     = @"^\\s*$";


#pragma mark -
#pragma mark Internal methods

@interface BXEmulatorConfiguration ()

//Parses a DOSBox-formatted configuration string and sets sections and settings from it
- (void) _parseSettingsFromString: (NSString *)configuration;

//The inverse of the above: returns a dictionary of sections and settings
//as a DOSBox-format configuration string.
- (NSString *) _formattedStringFromSettings;

//Returns an NSString-formatted comment
+ (NSString *) _formatAsComment: (NSString *)comment wrappedAtLineLength: (NSUInteger)wordWrap;

@end


@implementation BXEmulatorConfiguration
@synthesize preamble = _preamble;
@synthesize startupCommandsPreamble = _startupCommandsPreamble;

#pragma mark -
#pragma mark Initialization and teardown

+ (id) configurationWithString: (NSString *)configuration
{
	return [[(BXEmulatorConfiguration *)[self alloc] initWithString: configuration] autorelease];
}

+ (id) configurationWithContentsOfURL: (NSURL *)URL error: (out NSError **)outError
{
	return [[(BXEmulatorConfiguration *)[self alloc] initWithContentsOfURL: URL error: outError] autorelease];
}

+ (id) configurationWithContentsOfFile: (NSString *)filePath error: (out NSError **)outError
{
    return [self configurationWithContentsOfURL: [NSURL fileURLWithPath: filePath] error: outError];
}

+ (id) configuration
{
	return [[[self alloc] init] autorelease];
}


- (id) initWithContentsOfURL: (NSURL *)URL error: (out NSError **)outError
{
	NSString *fileContents = [NSString stringWithContentsOfURL: URL
                                                  usedEncoding: NULL
                                                         error: outError];

	if (fileContents)
	{
		self = [self initWithString: fileContents];
	}
	
	//If there was any problem loading the file, don't continue with initialization
	else
	{
        [self release];
		return nil;
	}
    return self;
}

- (id) initWithString: (NSString *)configuration
{
	if ((self = [self init]))
	{
		[self _parseSettingsFromString: configuration];
	}
	return self;
}

- (id) initWithSettings: (NSDictionary *)settings
{
	if ((self = [self init]))
	{
		[self addSettingsFromDictionary: settings];
	}
	return self;
}
		 
- (id) init
{
	if ((self = [super init]))
	{
		_sections = [[NSMutableDictionary alloc] initWithCapacity: BXConfigurationNumKnownSections];
	}
	return self;
}

- (void) dealloc
{
    self.preamble = nil;
    self.startupCommandsPreamble = nil;
	[_sections release], _sections = nil;
	[super dealloc];
}


#pragma mark -
#pragma mark Persisting configurations

- (BOOL) writeToFile: (NSString *)filePath error: (out NSError **)outError
{
    return [self writeToURL: [NSURL fileURLWithPath: filePath] error: outError];
}

- (BOOL) writeToURL: (NSURL *)URL error: (out NSError **)outError
{
	NSString *formattedString = self.description;
	return [formattedString writeToURL: URL atomically: YES encoding: NSUTF8StringEncoding error: outError];
}

- (NSString *) description
{
	return [self _formattedStringFromSettings];
}


#pragma mark -
#pragma mark Setting and getting individual settings

- (void) setValue: (NSString *)settingValue
           forKey: (NSString *)settingName
        inSection: (NSString *)sectionName
{
	//The autoexec section is an array, not a dictionary, and must be accessed with different methods
	NSAssert(![sectionName isEqualToString: @"autoexec"],
			 @"Startup commands should be set with setStartupCommands: or addStartupCommand:");
	
	NSMutableDictionary *section = [_sections objectForKey: sectionName];
		
	if (section)
	{
		[section setObject: settingValue forKey: settingName];
	}
	else
	{
		//If the section doesn't exist yet, just add a new one
		[self setSettings: [NSDictionary dictionaryWithObject: settingValue forKey: settingName]
			   forSection: sectionName];
	}
}

- (NSString *) valueForKey: (NSString *)settingName inSection: (NSString *)sectionName
{
	//The autoexec section is an array, not a dictionary, and must be accessed with different methods
	NSAssert(![sectionName isEqualToString: @"autoexec"],
			 @"Startup commands should be retrieved with [BXEmulatorConfiguration startupCommands].");
	
	return [[_sections objectForKey: sectionName] objectForKey: settingName];
}

- (void) removeValueForKey: (NSString *)settingName inSection: (NSString *)sectionName
{
	//The autoexec section is an array, not a dictionary, and must be accessed with different methods
	NSAssert(![sectionName isEqualToString: @"autoexec"],
			 @"Startup commands should be removed with [BXEmulatorConfiguration removeStartupCommand].");
	
	[[_sections objectForKey: sectionName] removeObjectForKey: settingName];
}


#pragma mark -
#pragma mark Setting and getting startup commands

- (NSArray *) startupCommands
{
	return [_sections objectForKey: @"autoexec"];
}

- (void) setStartupCommands: (NSArray *)commands
{
    if (commands)
    {
        NSMutableArray *mutableCommands = [commands mutableCopy];
        [_sections setObject: mutableCommands forKey: @"autoexec"];
        [mutableCommands release];
    }
    else
    {
        [self removeStartupCommands];
    }
}

- (void) removeStartupCommands
{
	[self removeSection: @"autoexec"];
}

- (void) addStartupCommand: (NSString *)command
{
	NSMutableArray *commands = [_sections objectForKey: @"autoexec"];
	if (commands)
	{
		[commands addObject: command];
	}
	else
	{
		//If we don't have an autoexec section yet, create a new one
        self.startupCommands = [NSMutableArray arrayWithObject: command];
	}
}

- (void) addStartupCommands: (NSArray *)newCommands
{
    if (!newCommands.count) return;
    
	NSMutableArray *commands = [_sections objectForKey: @"autoexec"];
	if (commands)
	{
		[commands addObjectsFromArray: newCommands];
	}
	else
	{
		//If we don't have an autoexec section yet, just create a new one
        self.startupCommands = commands;
	}
}

- (void) removeStartupCommand: (NSString *)command
{
	NSMutableArray *commands = [_sections objectForKey: @"autoexec"];
	[commands removeObject: command];
}


#pragma mark -
#pragma mark Setting and getting sections

- (NSDictionary *) settings
{
	NSMutableDictionary *settings = [_sections mutableCopy];
	
	//Remove the startup commands from our returned dictionary
	[settings removeObjectForKey: @"autoexec"];
	return [settings autorelease];
}

- (BOOL) isEmpty
{
	//If any section has any content, we're not empty
	for (id section in _sections.objectEnumerator)
        if ([section count] > 0) return NO;
    
	return YES;
}

- (NSDictionary *) settingsForSection: (NSString *)sectionName
{
	//The autoexec section is an array, not a dictionary, and must be accessed with different methods
	NSAssert(![sectionName isEqualToString: @"autoexec"],
			 @"Startup commands should be accessed with [BXEmulatorConfiguration startupCommands].");
	return [_sections objectForKey: sectionName];
}

- (void) setSettings: (NSDictionary *)newSettings forSection: (NSString *)sectionName
{
    if (newSettings)
    {
        NSMutableDictionary *section = [newSettings mutableCopy];
        [_sections setObject: section forKey: sectionName];
        [section release];
    }
    else
    {
        [self removeSection: sectionName];
    }
}

- (void) addSettings: (NSDictionary *)newSettings toSection: (NSString *)sectionName
{   
	//The autoexec section is an array, not a dictionary, and must be accessed with different methods
	NSAssert(![sectionName isEqualToString: @"autoexec"],
			 @"Startup commands should be added with [BXEmulatorConfiguration addStartupCommands:].");
	
    if (!newSettings.count)
        return;
    
	NSMutableDictionary *section = [_sections objectForKey: sectionName];
	if (section)
	{
		[section addEntriesFromDictionary: newSettings];
	}
	else
	{
		//If the section doesn't exist yet, then use the settings dictionary itself
		[self setSettings: newSettings forSection: sectionName];
	}
}

- (void) removeSection: (NSString *)sectionName
{
	[_sections removeObjectForKey: sectionName];
}


#pragma mark -
#pragma mark Importing and merging settings

- (void) addSettingsFromDictionary: (NSDictionary *)newSettings
{
	for (NSString *sectionName in newSettings.keyEnumerator)
	{
		id section = [newSettings objectForKey: sectionName];
		
        if ([sectionName isEqualToString: @"autoexec"])
            [self addStartupCommands: section];
		else
            [self addSettings: section toSection: sectionName];
	}
}

- (void) addSettingsFromConfiguration: (BXEmulatorConfiguration *)configuration
{
	NSDictionary *settings = configuration.settings;
	if (settings.count)
        [self addSettingsFromDictionary: settings];
	
	NSArray *startupCommands = configuration.startupCommands;
	if (startupCommands.count)
        [self addStartupCommands: startupCommands];
}

- (void) excludeDuplicateSettingsFromConfiguration: (BXEmulatorConfiguration *)configuration
{
	//First go through all our defined settings, stripping those that are the same in both configurations
	for (NSString *sectionName in self.settings)
	{
		NSDictionary *section = [self settingsForSection: sectionName];
        //Note that we iterate allKeys rather than keyEnumerator as we will be modifying
        //the dictionary's keys during iteration, which is not supported by enumerators.
		for (NSString *settingName in section.allKeys)
		{
			NSString *ourValue		= [self valueForKey: settingName inSection: sectionName];
			NSString *theirValue	= [configuration valueForKey: settingName inSection: sectionName];
			
			//Remove our own value if it's identical to the one in the configuration we're comparing to
			if ([ourValue isEqualToString: theirValue])
				[self removeValueForKey: settingName inSection: sectionName];
		}
	}
	
	//Now, eliminate duplicate startup commands too.
	//IMPLEMENTATION NOTE: for now we leave the startup commands alone unless the two sets
	//have exactly the same commands in the same order. There's too many risks involved 
	//for us to remove partial sets of duplicate startup commands.
	if ([self.startupCommands isEqualToArray: configuration.startupCommands])
		[self removeStartupCommands];
}


#pragma mark -
#pragma mark Internal parsing methods

- (void) _parseSettingsFromString: (NSString *)configuration
{
	NSString *sectionName = nil;
	BOOL isInAutoexec = NO;
		
	//Walk over every line of the configuration string
	for (NSString *line in configuration.lineEnumerator)
	{
		//Ignore empty and comment lines
		if (line.length &&
            ![line isMatchedByRegex: BXEmulatorConfigurationCommentFormat] &&
            ![line isMatchedByRegex: BXEmulatorConfigurationEmptyFormat])
		{
			//Check if this line is a section declaration, and change our current section if so.
			NSString *sectionNameMatch = [line stringByMatching: BXEmulatorConfigurationSectionFormat capture: 1];
			if (sectionNameMatch)
			{
				//Ensure all section names are lowercase, even if we match uppercase
				sectionName	= sectionNameMatch.lowercaseString;
				isInAutoexec = [sectionName isEqualToString: @"autoexec"];
			}
			
            //Otherwise, put this line under the current section.
			else if (sectionName)
			{
				//If we're within an autoexec section block, then treat every line as a command.
				if (isInAutoexec)
				{
					[self addStartupCommand: line];
				}
				//Otherwise, treat the line as a setting declaration.
				else
				{
					NSArray *settingMatch = [line captureComponentsMatchedByRegex: BXEmulatorConfigurationSettingFormat];
					
					//We expect two substrings from this match: less or more means a malformed setting line.
					if (settingMatch.count == 3)
					{
                        NSString *settingName   = [settingMatch objectAtIndex: 1];
                        NSString *settingValue  = [settingMatch objectAtIndex: 2];
                        
						//Always lowercase setting names, even though we can match uppercase versions
						settingName     = settingName.lowercaseString;
						settingValue	= [settingValue stringByTrimmingCharactersInSet:
												   [NSCharacterSet whitespaceAndNewlineCharacterSet]];
                        
						[self setValue: settingValue
                                forKey: settingName
                             inSection: sectionName];
					}	
				}
			}			
		}
	}
}

- (NSString *) _formattedStringFromSettings
{
	NSMutableString *formattedString = [NSMutableString stringWithCapacity: BXConfigurationInitialFormattedStringSize];
	
	//Add the initial header comment, if we have one
	if (self.preamble.length)
	{
		NSString *preambleComment = [self.class _formatAsComment: self.preamble
                                             wrappedAtLineLength: BXConfigurationWordWrap];
		[formattedString appendFormat: @"%@\n", preambleComment, nil];
	}
	
    NSDictionary *settings = self.settings;
	for (NSString *sectionName in settings.keyEnumerator)
	{
		NSDictionary *section = [settings objectForKey: sectionName];
		
		//Don't bother writing out empty sections
		if (section.count)
		{
			//Add a header for the section
			[formattedString appendFormat: @"\n[%@]\n", sectionName, nil];
			
			for (NSString *settingName in section.keyEnumerator)
			{
				NSString *settingValue = [section objectForKey: settingName];
				[formattedString appendFormat: @"%@=%@\n", settingName, settingValue, nil];
			}
		}
	}

	//Now add the startup commands to the end
	NSArray *commands = self.startupCommands;
	if (self.startupCommandsPreamble || commands.count)
	{
		//Add a header for the section
		[formattedString appendString: @"\n[autoexec]\n"];
		
		//Add the header comment if one was provided
		if (self.startupCommandsPreamble.length)
		{
			NSString *startupPreambleComment = [self.class _formatAsComment: self.startupCommandsPreamble
                                                        wrappedAtLineLength: BXConfigurationWordWrap];
			[formattedString appendFormat: @"%@\n", startupPreambleComment, nil];
		}
		
		for (NSString *command in commands)
		{
			[formattedString appendFormat: @"%@\n", command, nil];
		}
	}
	
	//Aaaand we're done!
	return formattedString;
}

+ (NSString *) _formatAsComment: (NSString *)comment wrappedAtLineLength: (NSUInteger)lineLength
{
	NSString *joiner = @"\n# ";
	lineLength -= joiner.length + 1; //Compensate for the extra joining characters
	NSArray *commentLines = [comment componentsSplitAtLineLength: lineLength atWordBoundaries: YES];
	
	
	NSString *commentedString = [NSString stringWithFormat: @"# %@\n", [commentLines componentsJoinedByString: joiner]];
	return commentedString;
}

@end