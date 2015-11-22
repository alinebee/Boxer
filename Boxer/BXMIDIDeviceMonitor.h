/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXMIDIDeviceMonitor is used for scanning connected MIDI devices to find MT-32s and listening
//for device connections/disconnections. It is formulated as an NSThread subclass which runs
//in the background until cancelled.
//(This work is moved to a thread because CoreMIDI initialization is fairly costly, and would
//otherwise block application startup. Besides improved startup time, there are no other benefits.)


#import <Foundation/Foundation.h>
#import <CoreMIDI/CoreMIDI.h>
#import "ADBContinuousThread.h"

NS_ASSUME_NONNULL_BEGIN

@class BXMIDIInputListener;
@protocol BXMIDIInputListenerDelegate <NSObject>

@optional

/// Sent whenever the listener receives a new batch of data. data contains the chunk just
/// received: for the full data received so far, call <code>[listener receivedData]</code>.
- (void) MIDIInputListener: (BXMIDIInputListener *)listener receivedData: (NSData *)data;

/// Sent when the listener has gone for its timeout period without receiving any data.
/// If the return value is <code>YES</code>, the listener will stop listening and close its connection.
/// (If the delegate does not implement this method, the listener assumes the answer is yes.)
- (BOOL) MIDIInputListenerShouldStopListeningAfterTimeout: (BXMIDIInputListener *)listener;

@end

@interface BXMIDIDeviceMonitor : ADBContinuousThread <BXMIDIInputListenerDelegate>
{
    MIDIClientRef _client;
    MIDIPortRef _outputPort;
    MIDIPortRef _inputPort;
    NSMutableArray *_discoveredMT32s;
    NSMutableArray *_listeners;
}

/// An array of unique destination IDs for MT-32s found during our scan.
/// This will be populated and depopulated as devices are added and removed.
/// This property is thread-safe and key-value-coding compliant, though KVC
/// notifications will be sent on the operation's thread.)
@property (readonly) NSArray<NSNumber*> *discoveredMT32s;

@end


//BXMIDIInputListener attaches to a MIDI source on a specified port,
//and tracks the raw MIDI data it receives from that source, sending messages
//to its delegate whenever new data arrives or the connection times out
//(stops sending data).

//BXMIDIDeviceBrowser uses instances of BXMIDIInputListener to track the sources
//to which it is listening, to sniff the data coming from those ports in response
//to its requests, and to clean up source connections when they're no longer needed.

//Note that while BXMIDIListener receives MIDI data on a dedicated CoreMIDI thread,
//it always delivers notifications about that data on the thread upon which
//listenToSource:onPort:contextInfo was called.

@interface BXMIDIInputListener : NSObject
{
    __unsafe_unretained id <BXMIDIInputListenerDelegate> _delegate;
    MIDIPortRef _port;
    MIDIEndpointRef _source;
    void * _contextInfo;
    NSTimeInterval _timeout;
    NSMutableData *_receivedData;
    NSThread *_notificationThread;
}

# pragma mark -
# pragma mark Properties

//Whether the listener is currently listening to a source.
@property (readonly, nonatomic, getter=isListening) BOOL listening;

//The port on which the listener is listening, and the source to which it is listening.
//Set by listenToSource:onPort:contextInfo, and cannot be set directly.
@property (readonly, nonatomic) MIDIPortRef port;
@property (readonly, nonatomic) MIDIEndpointRef source;

//The context info associated with the listening connection.
//Set by listenToSource:onPort:contextInfo, and cannot be set directly.
@property (readonly, nonatomic) void *contextInfo;

//The data this listener has received so far.
@property (readonly, nonatomic) NSData *receivedData;

//How long the listener will wait between data packets before sending
//a portListenerDidTimeOut: message to the delegate and/or disconnecting.
//Defaults to 1 second.
//Set to 0 to prevent timeout altogether, in which case the listener must
//be told to stop manually with stopListening.
@property (assign, nonatomic) NSTimeInterval timeout;

//The delegate to which notification messages will be sent.
@property (assign, nonatomic, nullable) id <BXMIDIInputListenerDelegate> delegate;


# pragma mark -
# pragma mark Methods

/// Creates and returns an input port set up on the specified client,
/// with a callback that will dispatch received messages to BXMIDIPortListener
/// objects. Returns NULL and populates outError if the port could not be created.
/// (This port will be owned by the calling context, and can be disposed of
/// with \c MIDIPortDispose once it is no longer needed.)
+ (MIDIPortRef) createListeningPortForClient: (MIDIClientRef)client
                                    withName: (NSString *)portName
                                       error: (NSError **)outError;

/// Returns a new listener instance assigned to the specified delegate.
- (instancetype) initWithDelegate: (id <BXMIDIInputListenerDelegate>)delegate;

/// Start listening for input on the specified source, with the specified contextInfo
/// (which is not retained). Returns \c YES if the listener is now attached and listening,
/// \c NO if there was an error.
- (BOOL) listenToSource: (MIDIEndpointRef)source
                 onPort: (MIDIPortRef)port
            contextInfo: (void *)contextInfo;

/// Called by the port callback with the data just received.
- (void) receivePackets: (const MIDIPacketList *)packets;

/// Disconnect from the source, if listening. Called automatically when the listener
/// times out, unless the delegate returns \c NO to <code>MIDIInputListenerShouldStopListeningAfterTimeout:</code>.
- (void) stopListening;

@end

NS_ASSUME_NONNULL_END
