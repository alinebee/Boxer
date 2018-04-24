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


#import <Cocoa/Cocoa.h>
#import "BXFileTypes.h"

NS_ASSUME_NONNULL_BEGIN

/// The \c BXExecutableTypes category extends \c NSWorkspace to add methods for verifying MS-DOS executables.
/// The actual implementations behind these methods have been moved to BXFileTypes; this is a deprecated
/// interface.
@interface NSWorkspace (BXExecutableTypes)

/// Returns whether the file at the specified path is an executable that can be run by DOSBox.
/// Returns \c NO and populates outError if the executable type could not be determined.
- (BOOL) isCompatibleExecutableAtPath: (NSString *)filePath error: (out NSError **)outError;

/// Returns the executable type of the file at the specified path.
/// If the executable type cannot be determined, \c outError will be populated with the reason.
- (BXExecutableType) executableTypeAtPath: (NSString *)path error: (out NSError **)outError;

@end

NS_ASSUME_NONNULL_END
