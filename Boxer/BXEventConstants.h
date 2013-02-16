/*
 *  Copyright (c) 2013, Alun Bestor (alun.bestor@gmail.com)
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without modification,
 *  are permitted provided that the following conditions are met:
 *
 *		Redistributions of source code must retain the above copyright notice, this
 *	    list of conditions and the following disclaimer.
 *
 *		Redistributions in binary form must reproduce the above copyright notice,
 *	    this list of conditions and the following disclaimer in the documentation
 *      and/or other materials provided with the distribution.
 *
 *	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 *	ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 *	WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 *	IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 *	INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 *	BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
 *	OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 *	WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *	ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *	POSSIBILITY OF SUCH DAMAGE.
 */

//BXEventConstants (re)defines some useful constants for handling NSEvents.

#import <Cocoa/Cocoa.h>

//A sufficiently large number that exceeds the highest virtual keycode.
//Used as the arbitrary length for arrays of key mappings.
#define BXMaxSystemKeyCode 256

//These correspond to NSEvent's mouse button numbers
typedef enum {
	BXMouseButtonLeft	= 0,
	BXMouseButtonRight	= 1,
	BXMouseButtonMiddle	= 2,
    BXMouseButtonMax    = 3
} BXMouseButton;


//These correspond to NSEvent's pressedMouseButton masks
enum {
	BXNoMouseButtonsMask	= 0,
	BXMouseButtonLeftMask	= 1U << BXMouseButtonLeft,
	BXMouseButtonRightMask	= 1U << BXMouseButtonRight,
	BXMouseButtonMiddleMask	= 1U << BXMouseButtonMiddle,
	
	BXMouseButtonLeftAndRightMask = BXMouseButtonLeftMask | BXMouseButtonRightMask
};

typedef NSUInteger BXMouseButtonMask;


//Modifier flag constants for left- and right-side modifier keys, copied from IOKit/IOLLEvent.h.
//Allows us to distinguish these for sending keypresses for modifier keys.

//IMPLEMENTATION NOTE: these are combined with their respective device-independent modifier masks,
//to ensure that modifier flags we compare against do actually represent a key event of that type:
//this avoids collisions with other unrelated device-dependent flags.
enum {
	BXLeftControlKeyMask	= 0x00000001 | NSControlKeyMask,
	BXLeftShiftKeyMask		= 0x00000002 | NSShiftKeyMask,
	BXRightShiftKeyMask		= 0x00000004 | NSShiftKeyMask,
	BXLeftCommandKeyMask	= 0x00000008 | NSCommandKeyMask,
	BXRightCommandKeyMask	= 0x00000010 | NSCommandKeyMask,
	BXLeftAlternateKeyMask	= 0x00000020 | NSAlternateKeyMask,
	BXRightAlternateKeyMask	= 0x00000040 | NSAlternateKeyMask,
	BXRightControlKeyMask	= 0x00002000 | NSControlKeyMask
};
