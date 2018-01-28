//
//  BBIconDropzone.m
//  Boxer Bundler
//
//  Created by Alun Bestor on 15/08/2012.
//  Copyright (c) 2012 Alun Bestor. All rights reserved.
//

#import "BBIconDropzone.h"

@implementation BBIconDropzone

- (id) initWithFrame: (NSRect)frame
{
    self = [super initWithFrame: frame];
    if (self)
    {
        NSArray *registeredTypes = self.registeredDraggedTypes;
        [self registerForDraggedTypes: [registeredTypes arrayByAddingObject: NSFilenamesPboardType]];
    }
    
    return self;
}

- (BOOL) performDragOperation: (id <NSDraggingInfo>)sender
{
    NSPasteboard *pboard = [sender draggingPasteboard];
    
    if ([pboard.types containsObject: NSFilenamesPboardType])
    {
        NSArray *filePaths = [pboard propertyListForType: NSFilenamesPboardType];
        NSString *lastFilePath = filePaths.lastObject;
        
        if (lastFilePath)
        {
            BOOL dropSucceeded = [super performDragOperation: sender];
            
            if (dropSucceeded)
            {
                self.lastDroppedImageURL = [NSURL fileURLWithPath: lastFilePath isDirectory: NO];
                return YES;
            }
        }
    }
    return NO;
}

@end
