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

extern const int ProjectorResolutionWidth;
extern const int ProjectorResolutionHeight;
extern const CGSize DefaultMediaFrameSize;

@class PFGeoPoint;

@interface ASAppDelegate : NSObject <NSApplicationDelegate, CLLocationManagerDelegate, NSWindowDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSTextField *markerId;
//@property (weak) IBOutlet WebView *webView;


@property (strong) CLLocationManager *locationManager;
@property (strong) CLLocation *currentLocation;

- (IBAction)runButtonPressed:(id)sender;
- (IBAction)calibrateButtonPressed:(id)sender;
- (IBAction)detectButtonPressed:(id)sender;


- (void)detectMarkerId:(int)markerId atAbsPosition:(CGPoint)absPosition;
- (void)playVideoForWebView:(WebView *)webView withVideoId:(NSString *)videoId;
- (void)showNotAssignedWarningForplayVideoForWebView:(WebView *)webView;
- (void)createDisplayWithFrame:(CGRect)frame;


////
@property BOOL isQuerying;
@property CGPoint corner_lt, corner_rt, corner_rb, corner_lb;
//@property (strong, nonatomic) NSMutableArray *markers;
@property (strong, nonatomic) NSMutableDictionary *mediaFrames;
- (CGPoint)positionRelativeToProjection:(CGPoint)absPosiotn;


@end
