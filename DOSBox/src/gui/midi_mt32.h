#include "MT32Emu/mt32emu.h"
#include "mixer.h"
#include "control.h"
#include "SDL_thread.h"
//--Added 2011-09-22 by Alun Bestor to allow Boxer to hook into MT-32 emulation. 
#import "BXCoalfaceMT32.h"
//--End of modifications

#include <iostream>
#include <string>

using namespace std;
//#define MT32MULTICORE 1
#ifdef MT32MULTICORE
static inline void cpuID(unsigned i, unsigned regs[4]) { 
   __asm__ __volatile__
   ("cpuid" : "=a" (regs[0]), "=b" (regs[1]), "=c" (regs[2]), "=d" (regs[3]): "a" (i), "c" (0));
   // ECX is set to zero for CPUID function 4
}  

static inline int cpu_check(void) {
    unsigned regs[4]; 
    char vendor[12];
    cpuID(0, regs);
    ((unsigned *)vendor)[0] = regs[1]; // EBX
    ((unsigned *)vendor)[1] = regs[3]; // EDX
    ((unsigned *)vendor)[2] = regs[2]; // ECX
    string cpuVendor = string(vendor, 12); 

    // Get CPU features
    cpuID(1, regs);
    unsigned cpuFeatures = regs[3]; // EDX 
    if (cpuVendor == "GenuineIntel" && cpuFeatures & (1 << 28)) { // HTT bit
        // Logical core count per CPU
        cpuID(1, regs);     unsigned logical = (regs[1] >> 16) & 0xff; // EBX[23:16]
        unsigned cores = logical;

        if (cpuVendor == "GenuineIntel") {
           // Get DCP cache info
           cpuID(4, regs);
           cores = ((regs[0] >> 26) & 0x3f) + 1; // EAX[31:26] + 1
        } else if (cpuVendor == "AuthenticAMD") {
           // Get NC: Number of CPU cores - 1
           cpuID(0x80000008, regs);
           cores = ((unsigned)(regs[2] & 0xff)) + 1; // ECX[7:0] + 1
        } else return 1;
        return cores;
   }
   return 0;
}
#endif

MT32Emu::Synth *_usesynth;
MixerChannel *mt32chan = NULL;
bool mt32ReverseStereo = false;

struct mt32 {
#ifdef MT32MULTICORE
	SDL_mutex * mutex;
	SDL_semaphore * sem;
	SDL_Thread * thread;
    bool multicore;
#endif
	volatile bool running, busy;

	Bit8u len, play;
	Bit8u Temp[MIXER_BUFSIZE], msg[SYSEX_SIZE];
};

void ReverseStereo(Bitu len, Bit16s *buf) {
	for(Bitu i = 0; i < len; i++) {
		Bit16s left = *buf;
		Bit16s right = buf[1];
		*buf++ = right;
		*buf++ = left;
	}
}

#ifdef MT32MULTICORE
static int MT32_Thread(void*) {
	SDL_LockMutex(mt32.mutex);

	while(mt32.running) {

		Bitu len;
		if(!(mt32.play) && !(mt32.len)) {
			SDL_UnlockMutex(mt32.mutex);
			SDL_SemWait(mt32.sem);
			SDL_LockMutex(mt32.mutex);
		}

		mt32.busy = true;
		while(mt32.play) {
			len = mt32.play;
			Bit32u *tmp = ((Bit32u*)mt32.msg);
			SDL_UnlockMutex(mt32.mutex);

			while(len--) {
				_usesynth->playMsg(*tmp++);
			}

			SDL_LockMutex(mt32.mutex);
			len = tmp-(Bit32u*)mt32.msg;
			mt32.play -= len;
			if(mt32.play) SDL_memmove(mt32.msg, tmp, mt32.play<<2);
		}

		while(mt32.len) {
			len = (mt32.len>>2) < MIXER_BUFSIZE ? mt32.len : MIXER_BUFSIZE<<2;
			mt32.len -= len;

#ifdef MT32DEBUG
			if(mt32.len) LOG_MSG("MT32:WARNING: len left (%d)", mt32.len);
#endif

			SDL_UnlockMutex(mt32.mutex);
			_usesynth->render((Bit16s *)mt32.Temp, len);
			if (mt32ReverseStereo) {
				ReverseStereo(len, (Bit16s *)MixTemp);
			}
			mt32chan->AddSamples_s16(len,(Bit16s *)mt32.Temp);
			SDL_LockMutex(mt32.mutex);
			break;
		}
		mt32.busy = false;
	}

	SDL_UnlockMutex(mt32.mutex);
	return 0;
}
#endif

static void MT32_CallBack(Bitu len) {
#ifdef MT32MULTICORE
    if(mt32.multicore) {
    	SDL_LockMutex(mt32.mutex);
    	mt32.len += len;
    	SDL_UnlockMutex(mt32.mutex);
    	SDL_SemPost(mt32.sem);
    } else {
#endif
       _usesynth->render((Bit16s *)MixTemp, len);
			 if (mt32ReverseStereo) {
					ReverseStereo(len, (Bit16s *)MixTemp);
			 }
       mt32chan->AddSamples_s16(len,(Bit16s *)MixTemp);
#ifdef MT32MULTICORE
    }
#endif
}

static int report(void *userData, MT32Emu::ReportType type, const void *reportData) {
   switch(type) {
   case MT32Emu::ReportType_errorControlROM:
      LOG_MSG("MT32:Couldn't find control files");
      break;
   case MT32Emu::ReportType_errorPCMROM:
      LOG_MSG("MT32:Couldn't open MT32_PCM.ROM file");
      break;
   default:
      //LOG(LOG_ALL,LOG_NORMAL)("MT32: Report %d",type);
      break;
   }
   return 0;
}

class MidiHandler_mt32: public MidiHandler {
private:
   MT32Emu::Synth *_synth;
   int _outputRate;
   bool isOpen;

public:
   MidiHandler_mt32() : isOpen(false),MidiHandler() {};
   const char * GetName(void) { return "mt32";};
   bool Open(const char * conf) {
      MT32Emu::SynthProperties tmpProp;
      memset(&tmpProp, 0, sizeof(tmpProp));
      tmpProp.sampleRate = 32000;

      tmpProp.useDefaultReverb = false;
      tmpProp.useReverb = true;
      tmpProp.reverbType = 0;
      tmpProp.reverbTime = 5;
      tmpProp.reverbLevel = 3;
      tmpProp.userData = this;
      //tmpProp.printDebug = &vdebug;
      //--Modified 2011-09-22 by Alun Bestor to use Boxer's own callbacks instead.
      //tmpProp.report = &report;
      tmpProp.report = &boxer_reportMT32Message;
      tmpProp.openFile = &boxer_openMT32ROM;
      tmpProp.closeFile = &boxer_closeMT32ROM;
      tmpProp.printDebug = &boxer_logMT32DebugMessage;
      //--End of modifications 
       
      _synth = new MT32Emu::Synth();
      if (_synth->open(tmpProp)==0) {
         LOG(LOG_ALL,LOG_ERROR)("MT32:Error initialising emulation");
         return false;
      }
      _usesynth=_synth;

			Section_prop* section=static_cast<Section_prop *>(control->GetSection("midi"));
      if(strcmp(section->Get_string("mt32reverb.mode"),"auto")) {
					Bit8u reverbsysex[] = {0x10, 0x00, 0x01, 0x00, 0x05, 0x03};
					reverbsysex[3] = (Bit8u)atoi(section->Get_string("mt32reverb.mode"));
					reverbsysex[4] = (Bit8u)section->Get_int("mt32reverb.time");
					reverbsysex[5] = (Bit8u)section->Get_int("mt32reverb.level");
					_synth->writeSysex(16, reverbsysex, 6);
					_synth->setReverbOverridden(true);
      } else {
		      LOG_MSG("MT32:Using default reverb");
      }

      if(strcmp(section->Get_string("mt32DAC"),"auto")) {
				_synth->setDACInputMode((MT32Emu::DACInputMode)atoi(section->Get_string("mt32DAC")));
			}

      if(!strcmp(section->Get_string("mt32ReverseStereo"),"on")) {
				mt32ReverseStereo = true;
			} else {
				mt32ReverseStereo = false;
			}

			if (mt32chan == NULL)
          mt32chan=MIXER_AddChannel(MT32_CallBack,tmpProp.sampleRate,"MT32");

      mt32chan->Enable(true);

      /* Create MT32 thread */
#ifdef MT32MULTICORE
      mt32.multicore=(cpu_check()>1?true:false);
      if(mt32.multicore) {
          mt32.mutex = SDL_CreateMutex();
          mt32.sem = SDL_CreateSemaphore(0);
          mt32.running = true;
          mt32.busy = false;
          mt32.play = 0;
          mt32.thread = SDL_CreateThread(MT32_Thread, NULL);
      }
#endif
      return true;
   };

	 void Close(void) {
      if (!isOpen) return;
      mt32chan->Enable(false);
#ifdef MT32MULTICORE
      if(mt32.multicore) {
          mt32.running = false;
          SDL_SemPost(mt32.sem);
          SDL_WaitThread(mt32.thread, NULL);
          SDL_DestroyMutex(mt32.mutex);
      }
#endif
      _synth->close();
      delete _synth;
      _synth = NULL;
      _usesynth=_synth;
      isOpen=false;
   };

	 void PlayMsg(Bit8u * msg) {
#ifdef MT32MULTICORE
      if(mt32.multicore) {
          // Try to queue play commands
          SDL_LockMutex(mt32.mutex);
          // Playcommand buffer full?
          while(!(mt32.play < SYSEX_SIZE>>2)) {
            SDL_UnlockMutex(mt32.mutex);
            LOG_MSG("MT32:Playback buffer full...");
            SDL_LockMutex(mt32.mutex);
          }
          SDL_memcpy(mt32.msg+(mt32.play<<2), msg, sizeof(Bit32u));
          mt32.play ++;
          SDL_UnlockMutex(mt32.mutex);
          SDL_SemPost(mt32.sem);
     } else {
#endif
         //--Modified 2011-09-22 by Alun Bestor to fix endianness bug from byte-array casting.
          _synth->playMsg(boxer_MIDIMessageToLong(msg));
         //--End of modifications
#ifdef MT32MULTICORE
     }
#endif
   };

	 void PlaySysex(Bit8u * sysex,Bitu len) {
#ifdef MT32MULTICORE
      if(mt32.multicore) {
          SDL_LockMutex(mt32.mutex);
          while(mt32.busy) {
            SDL_UnlockMutex(mt32.mutex);
#ifdef MT32DEBUG
            LOG_MSG("MT32:Waiting to deliver sysex");
#endif
            SDL_LockMutex(mt32.mutex);
          }
      }
#endif
         
      if(sysex[0] == 0xf0) {
         _synth->playSysex(sysex, len);
      } else {
         _synth->playSysexWithoutFraming(sysex, len);
      }
#ifdef MT32MULTICORE
      if(mt32.multicore) SDL_UnlockMutex(mt32.mutex);
#endif
   };
};

MidiHandler_mt32 Midi_mt32;
