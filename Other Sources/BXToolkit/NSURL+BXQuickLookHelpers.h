/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import <Cocoa/Cocoa.h>

@interface NSURL (BXQuickLookHelpers)

//Returns a QuickLook thumbnail for the file at this URL, or nil if no thumbnail could be generated.
//pixelSize specifies the maximum pixel dimensions for the preview, without taking into account
//any UI scaling factors. The returned image is guaranteed to be *at most* this size;
//a smaller image may be returned.
//If useIconStyle is true, the thumbnail will be generated with the shadow and page-curl effects
//as seen in Finder.
//USAGE NOTE: this method is synchronous and can take a while to complete, so should be performed on a background thread.
- (NSImage *) quickLookThumbnailWithMaxSize: (NSSize)pixelSize iconStyle: (BOOL)useIconStyle;

@end
