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
#import "ASMarkerDetector.h"

extern const int ProjectorResolutionWidth;
extern const int ProjectorResolutionHeight;
extern NSSize DefaultMediaFrameSize;

#define PLAY 1
#define PAUSE 2

@class PFGeoPoint;

@interface ASAppDelegate : NSObject <NSApplicationDelegate, CLLocationManagerDelegate, NSWindowDelegate, ASDetectorDelegate>

@property (assign) IBOutlet NSWindow *window;

@property (strong) CLLocationManager *locationManager;
@property (strong) CLLocation *currentLocation;

@property (weak) IBOutlet NSImageView *anchorView0;
@property (weak) IBOutlet NSImageView *anchorView1;
@property (weak) IBOutlet NSImageView *anchorView2;
@property (weak) IBOutlet NSImageView *anchorView3;


- (void)detectMarkerId:(int)markerId atAbsPosition:(CGPoint)absPosition;
- (void)playVideoForWebView:(WebView *)webView withVideoId:(NSString *)videoId;
- (void)playImageForWebView:(WebView *)webView withImageURL:(NSString *)imageURL;
- (void)showNotAssignedWarningForplayVideoForWebView:(WebView *)webView;
- (void)createDisplayForMarker:(int)markerId WithData:(id)data andFrame:(CGRect)frame;

- (float)scaleRatioOfProjection;

////
@property BOOL isQuerying;
@property CGPoint corner_lt, corner_rt, corner_rb, corner_lb;
@property (strong, nonatomic) NSMutableDictionary *mediaFrames;
@property (nonatomic) NSMutableDictionary *playStatus;

- (CGPoint)positionRelativeToProjection:(CGPoint)absPosiotn;

- (NSRect)getFrameOfMarker:(NSNumber *)markerId;

- (void)setCornerLeftTop:(CGPoint)point;
- (void)setCornerRightTop:(CGPoint)point;
- (void)setCornerRightBottom:(CGPoint)point;
- (void)setCornerLeftBottom:(CGPoint)point;


@end
