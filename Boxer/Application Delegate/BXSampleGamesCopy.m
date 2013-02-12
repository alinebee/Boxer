/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXSampleGamesCopy.h"
#import "BXCoverArt.h"

@implementation BXSampleGamesCopy
@synthesize sourcePath, targetPath;

- (id) init
{
	if ((self = [super init]))
	{
		manager = [[NSFileManager alloc] init];
		workspace = [[NSWorkspace alloc] init];
	}
	return self;
}

- (id) initFromPath: (NSString *)source toPath: (NSString *)target
{
	if ((self = [self init]))
	{
		[self setSourcePath: source];
		[self setTargetPath: target];
	}
	return self;
}

- (void) dealloc
{
	[self setSourcePath: nil], [sourcePath release];
	[self setTargetPath: nil], [targetPath release];
	[manager release], manager = nil;
	[workspace release], workspace = nil;
	[super dealloc];
}

- (void) main
{
	if ([self isCancelled]) return;
	
	NSDictionary *attrs	= [NSDictionary dictionaryWithObject: [NSNumber numberWithBool: YES]
													  forKey: NSFileExtensionHidden];
	
	for (NSString *gamePath in [manager contentsOfDirectoryAtPath: sourcePath error: NULL])
	{
		if ([self isCancelled]) return;
		
		NSString *gameSource		= [sourcePath stringByAppendingPathComponent: gamePath];
		NSString *gameDestination	= [targetPath stringByAppendingPathComponent: gamePath];
		
		//If the folder already has a game of that name, don't copy the game
		//(we don’t want to overwrite someone's savegames)
		if (![manager fileExistsAtPath: gameDestination])
		{
			[manager copyItemAtPath: gameSource toPath: gameDestination error: NULL];
			[manager setAttributes: attrs ofItemAtPath: gameDestination error: NULL];
			
			NSString *gameName = [[gamePath lastPathComponent] stringByDeletingPathExtension];
			NSString *iconPath = [[NSBundle mainBundle] pathForResource: gameName
																 ofType: @"jpg"
															inDirectory: @"Sample Game Icons"];
			
			//Generate a cover art image from this icon (cheaper than storing a full icns file)
			if (iconPath)
			{
				NSImage *image = [[NSImage alloc] initWithContentsOfFile: iconPath];
				if (image)
				{
					NSImage *iconForGame = [BXCoverArt coverArtWithImage: image];
					[workspace setIcon: iconForGame forFile: gameDestination options: 0];
				}
				[image release];
			}
		}
	}	
}

@end
