/*
    SDL - Simple DirectMedia Layer
    Copyright (C) 1997-2003  Sam Lantinga

    This library is free software; you can redistribute it and/or
    modify it under the terms of the GNU Library General Public
    License as published by the Free Software Foundation; either
    version 2 of the License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Library General Public License for more details.

    You should have received a copy of the GNU Library General Public
    License along with this library; if not, write to the Free
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

    Sam Lantinga
    slouken@libsdl.org
*/
#include "SDL_config.h"

/* Subclass of NSWindow to fix genie effect and support resize events  */
@interface SDL_QuartzWindow : NSWindow
- (void) setFrame:(NSRect)frameRect display:(BOOL)flag;
- (id) initWithContentRect:(NSRect)contentRect styleMask:(unsigned int)styleMask backing:(NSBackingStoreType)backingType defer:(BOOL)flag;
- (void) applicationWillUnhide:(NSNotification*)aNotification;
- (void) applicationDidUnhide:(NSNotification*)aNotification;
- (void) applicationDidHide:(NSNotification*)aNotification;
@end


@interface SDL_QuartzWindowDelegate : NSObject
- (void)windowDidBecomeKey:(NSNotification *)aNotification;
- (void)windowDidResignKey:(NSNotification *)aNotification;
@end

/* Subclass of NSView to set cursor rectangle */
@interface SDL_QuartzView : NSView
- (void)resetCursorRects;
@end
