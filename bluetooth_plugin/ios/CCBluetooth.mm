#import "CCBluetooth.h"
#import <MultipeerConnectivity/MultipeerConnectivity.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <CoreLocation/CoreLocation.h>

#define PROXIMITY_UUID     @"6E34F5FD-7229-4605-A98B-1EEE610D55AB"

@interface BluetoothManager : NSObject <CBPeripheralManagerDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate, MCSessionDelegate, CLLocationManagerDelegate>
{
    // store c++ instance information related to this delegate
    void *object;
}

- (void)start:(NSString*)peerID :(NSString*)message;
- (void)stop;

@end

@implementation BluetoothManager
{
	MCNearbyServiceAdvertiser	*_nearbyServiceAdvertiser;
	MCPeerID					*_peerID;
	MCSession					*_session;
    
    CBPeripheralManager			*_peripheralManager;
	MCNearbyServiceBrowser      *_nearbyServiceBrowser;
    
	CLLocationManager           *_locationManager;
	NSUUID                      *_uuid;
	CLBeaconRegion              *_region;
    NSMutableArray              *_beacons;

    NSString                    *_message;
}

-(id)initWithDelegate:(void *)delegate
{
    self = [super init];
    if (self) {
	    object = delegate;

        _uuid = [[NSUUID alloc] initWithUUIDString:PROXIMITY_UUID];
        _region = [[CLBeaconRegion alloc] initWithProximityUUID:_uuid identifier:[_uuid UUIDString]];
    }
    
    return self;
}

- (void)start:(NSString*)peerID :(NSString*)message
{
    _message = message;

    _peerID = [[MCPeerID alloc] initWithDisplayName:peerID];
    _session = [[MCSession alloc] initWithPeer:_peerID];
    _session.delegate = (id<MCSessionDelegate>)self;
    
    _peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    
    _locationManager = [[CLLocationManager alloc] init];
    _locationManager.delegate = self;
    
    [_locationManager startRangingBeaconsInRegion:_region];
    
    [self performSelector:@selector(startAdvertise) withObject:nil afterDelay:0.5];
}

- (void)stop
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(startAdvertise) object:nil];

    [self stopAdvertise];
    
    if (_locationManager) {
        [_locationManager stopRangingBeaconsInRegion:_region];
        _locationManager.delegate = nil;
        _locationManager = nil;
    }
    
    [self stopBrowsing];
}

- (void)didChangeState:(NSDictionary*)info
{
    NSNumber *result = [info objectForKey:@"result"];
    NSNumber *status = [info objectForKey:@"status"];
    NSString *error = [info objectForKey:@"error"];
    NSString *peerID = [info objectForKey:@"peerID"];
    NSString *message = [info objectForKey:@"message"];
    
    bluetooth_plugin::CCBluetoothDelegate *pDelegate = (bluetooth_plugin::CCBluetoothDelegate*)object;
    if(pDelegate != NULL) {
        pDelegate->onResult([result intValue],
                            [status intValue],
                            [error cStringUsingEncoding:NSUTF8StringEncoding],
                            [peerID cStringUsingEncoding:NSUTF8StringEncoding],
                            [message cStringUsingEncoding:NSUTF8StringEncoding]);
    }
}

-(void)beaconing:(BOOL)flag
{
    NSLog(@"beaconing: %d", flag);
    
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:PROXIMITY_UUID];
    CLBeaconRegion *region = [[CLBeaconRegion alloc]
                              initWithProximityUUID:uuid
                              identifier:[uuid UUIDString]];
	
    NSDictionary *peripheralData = [region peripheralDataWithMeasuredPower:nil];
	
    if (flag)
        [_peripheralManager startAdvertising:peripheralData];
    else
        [_peripheralManager stopAdvertising];
}

- (void)startAdvertise
{
    NSLog(@"startAdvertise");
    
    [self beaconing:YES];
    
    NSDictionary *discoveryInfo = [[NSDictionary alloc] initWithObjectsAndKeys:[[UIDevice currentDevice] name], @"device name", nil];
    _nearbyServiceAdvertiser = [[MCNearbyServiceAdvertiser alloc] initWithPeer:_peerID discoveryInfo:discoveryInfo serviceType:@"connect-anyway"];
    _nearbyServiceAdvertiser.delegate = self;
    [_nearbyServiceAdvertiser startAdvertisingPeer];
}

- (void)stopAdvertise
{
    NSLog(@"stopAdvertise");
    
    [self beaconing:NO];
    
    [_nearbyServiceAdvertiser stopAdvertisingPeer];
}

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didNotStartAdvertisingPeer:(NSError *)error
{
    NSLog(@"advertiser:didNotStartAdvertisingPeer");
    if(error){
        NSLog(@"%@", [error localizedDescription]);
    }
}

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didReceiveInvitationFromPeer:(MCPeerID *)peerID withContext:(NSData *)context invitationHandler:(void (^)(BOOL accept, MCSession *session))invitationHandler
{
    if([_session.connectedPeers count]==0) {
        NSLog(@"New connection peer[%@-->%@]", peerID.displayName, _peerID.displayName);
    }
    else {
        NSLog(@"Already connected");
        [self performSelectorOnMainThread:@selector(communicateToPeer) withObject:nil waitUntilDone:NO];
    }
	
    invitationHandler(([_session.connectedPeers count] == 0 ? YES : NO), _session);
}

- (void)communicateToPeer
{
    [self sendMessage:_peerID.displayName];
}

- (void)sendMessage:(NSString *)message
{
    NSLog(@"sendMessage: %@", message);
    
    NSData *messageData = [message dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error;
    
    [_session sendData:messageData toPeers:_session.connectedPeers withMode:MCSessionSendDataReliable error:&error];
    if (error) {
        NSLog(@"Error sending message to peers [%@]", error);
    }
}

- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state
{
    NSLog(@"session:peer:didChangeState: %d", (int)MCSessionStateConnected);
    if (state == MCSessionStateConnected)
    {
        [self performSelectorOnMainThread:@selector(communicateToPeer) withObject:nil waitUntilDone:NO];
    }
}

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
    NSLog(@"peripheralManagerDidUpdateState");
}

- (void)locationManager:(CLLocationManager *)manager didStartMonitoringForRegion:(CLRegion *)region
{
    NSLog(@"locationManager:didStartMonitoringForRegion: %@", region.identifier);
    
    [_locationManager requestStateForRegion:region];
}

- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region
{
    NSLog(@"locationManager:didEnterRegion: %@", region.identifier);
    if ([region isKindOfClass:[CLBeaconRegion class]]) {
    }
}

- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region
{
    NSLog(@"locationManager:didExitRegion: %@", region.identifier);
    if ([region isKindOfClass:[CLBeaconRegion class]]) {
    }
}

- (void)locationManager:(CLLocationManager *)manager didDetermineState:(CLRegionState)state forRegion:(CLRegion *)region
{
    NSLog(@"locationManager:didDetermineState: %@", region.identifier);
    
    if ([region isKindOfClass:[CLBeaconRegion class]]) {
        switch (state) {
            case CLRegionStateInside:
                [self startBrowsing];
                break;
            case CLRegionStateOutside:
            case CLRegionStateUnknown:
                break;
        }
    }
}

- (void)locationManager:(CLLocationManager *)manager monitoringDidFailForRegion:(CLRegion *)region withError:(NSError *)error
{
    NSLog(@"monitoringDidFailForRegion:%@(%@)", region.identifier, error);
}

- (void)locationManager:(CLLocationManager *)manager didRangeBeacons:(NSArray *)beacons inRegion:(CLBeaconRegion *)region
{
    for(CLBeacon *beacon in beacons) {
        if((beacon.proximity == CLProximityNear)||(beacon.proximity == CLProximityImmediate)) {
            if(_nearbyServiceBrowser==nil) {
                NSLog(@"locationManager:didRangeBeacons:inRegion: %@", region.identifier);
                [self startBrowsing];
            }
        }
    }
}

- (void)locationManager:(CLLocationManager *)manager rangingBeaconsDidFailForRegion:(CLBeaconRegion *)region withError:(NSError *)error
{
    NSLog(@"locationManager:rangingBeaconsDidFailForRegion: %@(%@)", region.identifier, error);
}

- (void)startBrowsing
{
    NSLog(@"startBrowsing");
    _nearbyServiceBrowser = [[MCNearbyServiceBrowser alloc] initWithPeer:_peerID serviceType:@"connect-anyway"];
    _nearbyServiceBrowser.delegate = self;
    [_nearbyServiceBrowser startBrowsingForPeers];
}

- (void)stopBrowsing
{
    NSLog(@"stopBrowsing");
    [_nearbyServiceBrowser stopBrowsingForPeers];
}

- (void)browser:(MCNearbyServiceBrowser *)browser didNotStartBrowsingForPeers:(NSError *)error
{
    NSLog(@"browser:didNotStartBrowsingForPeers:");
    if(error){
        NSLog(@"[error localizedDescription] %@", [error localizedDescription]);
    }
}

- (void)browser:(MCNearbyServiceBrowser *)browser foundPeer:(MCPeerID *)peerID withDiscoveryInfo:(NSDictionary *)info
{
    NSLog(@"browser:foundPeer:withDiscoveryInfo:");
    if([_session.connectedPeers count] == 0) {
        NSLog(@"Send invitation peer[%@-->%@]", _peerID.displayName, peerID.displayName);
        [_nearbyServiceBrowser invitePeer:peerID toSession:_session withContext:[@"Welcome" dataUsingEncoding:NSUTF8StringEncoding] timeout:10];
    }
    else {
        NSLog(@"Already connected to other peer");
        [self performSelectorOnMainThread:@selector(communicateToPeer) withObject:nil waitUntilDone:NO];
    }
}

- (void)browser:(MCNearbyServiceBrowser *)browser lostPeer:(MCPeerID *)peerID
{
    NSLog(@"lost peer: %@", peerID.displayName);
}

- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID
{
    NSString *message = [[NSString alloc] initWithData:data encoding: NSUTF8StringEncoding];
    NSLog(@"Peer [%@] receive data (%@)", peerID.displayName, message);

    NSMutableDictionary *info = [[NSMutableDictionary alloc] init];
    
    [info setObject:[NSNumber numberWithInt:RESULT_RECEIVE_MESSAGE] forKey:@"result"];
    [info setObject:[NSNumber numberWithInt:STATUS_OK] forKey:@"status"];
    [info setObject:@"" forKey:@"error"];
    [info setObject:peerID.displayName forKey:@"peerID"];
    [info setObject:message forKey:@"message"];
    
    [self performSelectorOnMainThread:@selector(didChangeState:) withObject:info waitUntilDone:NO];
}

- (void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID
{
    NSLog(@"Received data over stream with name %@ from peer %@", streamName, peerID.displayName);
}

- (void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress
{
    NSLog(@"Start receiving resource [%@] from peer %@ with progress [%@]", resourceName, peerID.displayName, progress);
}

- (void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error
{
    NSLog(@"session:didFinishReceivingResourceWithName:fromPeer:atURL:withError:");
}

@end

namespace bluetooth_plugin
{
    BluetoothManager *_bluetooth = NULL;
    
    CCBluetooth::CCBluetooth(CCBluetoothDelegate* delegate)
    {
        _bluetooth = [[BluetoothManager alloc] initWithDelegate:(void *)delegate];
    }

    CCBluetooth::~CCBluetooth()
    {
        [_bluetooth stop];
        [_bluetooth release];
    }

    void CCBluetooth::start(const char *peerID, const char *message)
    {
        NSLog(@"start");
        
        [_bluetooth start:[NSString stringWithFormat:@"%s",  peerID]:[NSString stringWithFormat:@"%s",  message]];
    }
    
    void CCBluetooth::stop()
    {
        NSLog(@"stop");
        
        [_bluetooth stop];
    }
}
