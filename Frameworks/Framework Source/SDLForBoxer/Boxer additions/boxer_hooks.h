/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//This header gives Boxer access to various otherwise-private SDL internal functions by declaring
//them as exported symbols.

#ifndef _boxer_hooks_h
#define _boxer_hooks_h

#include "begin_code.h"
#ifdef __cplusplus
extern "C" {
#endif

//These permit us to send appropriate activate/deactivate notifications to the SDL event system, whilst bypassing SDL_QuartzDelegate and its ilk altogether.
extern DECLSPEC void SDLCALL boxer_SDLGrabInput();
extern DECLSPEC void SDLCALL boxer_SDLReleaseInput();
extern DECLSPEC void SDLCALL boxer_SDLInvalidateCursor();
extern DECLSPEC void SDLCALL boxer_SDLActivateApp();
extern DECLSPEC void SDLCALL boxer_SDLDeactivateApp();

#ifdef __cplusplus
}
#endif
#include "close_code.h"

#endif