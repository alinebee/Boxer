/*
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXErrorHelpers adds helper methods to NSError to make it nicer to work with.

#import <Foundation/Foundation.h>

@interface NSError (BXErrorHelpers)

//Returns YES if the error has the specified error domain and code, NO otherwise.
- (BOOL) matchesDomain: (NSString *)errorDomain code: (NSInteger)errorCode;

@end
