/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#include "boxer_hooks.h"
#include "SDL_QuartzVideo.h"
#include "SDL_QuartzWM.h"
#include "SDL_events.h"

//#undef cursor_visible

void boxer_SDLGrabInput()			{ QZ_DoActivate (current_video); }
void boxer_SDLReleaseInput()		{ QZ_DoDeactivate (current_video); }
void boxer_SDLInvalidateCursor()	{ SDL_PrivateAppActive (0, SDL_APPMOUSEFOCUS); /*current_video->hidden->cursor_visible = YES;*/ }
void boxer_SDLActivateApp()			{ SDL_PrivateAppActive (1, SDL_APPACTIVE); }
void boxer_SDLDeactivateApp()		{ SDL_PrivateAppActive (0, SDL_APPACTIVE); }