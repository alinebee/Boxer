/*
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#include <CoreMIDI/MIDIServices.h>

class MidiHandler_coremidi : public MidiHandler {
private:
	MIDIPortRef m_port;
	MIDIClientRef m_client;
	MIDIEndpointRef m_endpoint;
	MIDIPacket* m_pCurPacket;
public:
	MidiHandler_coremidi()  {m_pCurPacket = 0;}
	const char * GetName(void) { return "coremidi"; }
	bool Open(const char * conf) {
	
		// Get the MIDIEndPoint
		m_endpoint = 0;
		
		Bitu numDests = MIDIGetNumberOfDestinations();
	        Bitu destId = 0;
	        if(conf && conf[0]) destId = atoi(conf);
		if (destId < numDests)
		{
			m_endpoint = MIDIGetDestination(destId);
		}

		// Create a MIDI client and port
		MIDIClientCreate(CFSTR("MyClient"), 0, 0, &m_client);

		if (!m_client)
		{
			LOG_MSG("MIDI:coremidi: No client created.");
			return false;
		}

		MIDIOutputPortCreate(m_client, CFSTR("MyOutPort"), &m_port);

		if (!m_port)
		{
			LOG_MSG("MIDI:coremidi: No port created.");
			return false;
		}

		
		return true;
	}
	
	void Close(void) {
		// Stop any currently playing channels
		boxer_mute();
		
		// Dispose the port
		MIDIPortDispose(m_port);

		// Dispose the client
		MIDIClientDispose(m_client);

		// Dispose the endpoint
		MIDIEndpointDispose(m_endpoint);
	}
	
	void PlayMsg(Bit8u * msg) {
		// Acquire a MIDIPacketList
		Byte packetBuf[128];
		MIDIPacketList *packetList = (MIDIPacketList *)packetBuf;
		m_pCurPacket = MIDIPacketListInit(packetList);
		
		// Determine the length of msg
		Bitu len=MIDI_evt_len[*msg];
		
		// Add msg to the MIDIPacketList
		MIDIPacketListAdd(packetList, (ByteCount)sizeof(packetBuf), m_pCurPacket, (MIDITimeStamp)0, len, msg);
		
		// Send the MIDIPacketList
		MIDISend(m_port,m_endpoint,packetList);
	}
	
	void PlaySysex(Bit8u * sysex, Bitu len) {
		// Acquire a MIDIPacketList
		Byte packetBuf[SYSEX_SIZE*4];
		
		MIDIPacketList *packetList = (MIDIPacketList *)packetBuf;
		m_pCurPacket = MIDIPacketListInit(packetList);
		
		// Add msg to the MIDIPacketList
		MIDIPacketListAdd(packetList, (ByteCount)sizeof(packetBuf), m_pCurPacket, (MIDITimeStamp)0, len, sysex);
		
		// Send the MIDIPacketList
		MIDISend(m_port,m_endpoint,packetList);
	}
	
	//--Added 2011-04-16 by Alun Bestor to allow Boxer to mute/unmute MIDI output
	//This sends All Notes Off signals to channels 0-15. This has been tested on an MT-32
	//and is valid according to the MIDI spec (http://www.midi.org/techspecs/midimessages.php)
	void boxer_mute(void)
	{
#define BXChannelModeChangePrefix 176
#define BXAllNotesOffMessage 123
		if (m_port && m_endpoint)
		{
			Bit8u cmd[8] = {BXChannelModeChangePrefix, BXAllNotesOffMessage, 0, 0, 0, 0, 0, 0};
			Bitu i, numChannels = 16;
			
			for (i=0; i<numChannels; i++)
			{
				//Add the channel number to the mode-change prefix
				//to get the proper mode-change message
				cmd[0] += i;
				PlayMsg(cmd);
			}
		}
	}
	//This is a no-op, because playback will resume once the DOS game continues sending signals
	void boxer_unmute(void)	{ }
	//--End of modifications
};

MidiHandler_coremidi Midi_coremidi;

