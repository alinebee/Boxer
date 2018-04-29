/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "YRKSpinningProgressIndicator.h"

/// \c BXDOSWindowLoadingSpinner is a thin white progress spinner with a drop shadow,
/// intended for use on dark window backgrounds.
@interface BXHUDSpinningProgressIndicator : YRKSpinningProgressIndicator

@property (strong, nonatomic) NSShadow *dropShadow;

@end
