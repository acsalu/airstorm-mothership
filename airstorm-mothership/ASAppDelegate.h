//
//  ASAppDelegate.h
//  airstorm-mothership
//
//  Created by Acsa Lu on 6/21/13.
//  Copyright (c) 2013 com.nmlab-g7. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import <CoreLocation/CoreLocation.h>

@class PFGeoPoint;

@interface ASAppDelegate : NSObject <NSApplicationDelegate, CLLocationManagerDelegate, NSWindowDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSTextField *markerId;
@property (weak) IBOutlet WebView *webView;


@property (strong) CLLocationManager *locationManager;
@property (strong) CLLocation *currentLocation;

- (IBAction)runButtonPressed:(id)sender;
- (IBAction)calibrateButtonPressed:(id)sender;


- (void)detectMarkerId:(int)markerId;
- (void)playVideoForWebView:(WebView *)webView withVideoId:(NSString *)videoId;
- (void)showNotAssignedWarningForplayVideoForWebView:(WebView *)webView;
- (void)createDisplayWithFrame:(CGRect)frame;

@end
