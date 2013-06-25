//
//  ASAppDelegate.m
//  airstorm-mothership
//
//  Created by Acsa Lu on 6/21/13.
//  Copyright (c) 2013 com.nmlab-g7. All rights reserved.
//

#import "ASAppDelegate.h"
#import "ASCVUtility.h"
#import "ASMarkerDetector.h"
#import <ParseOSX/Parse.h>

const int ProjectorResolutionWidth = 1024;
const int ProjectorResolutionHeight = 768;
NSSize DefaultMediaFrameSize = {320, 180};

#define THRESHOLD_DISTANCE 0.3
#define THRESHOLD_TIME_INTERVAL 3600

@implementation ASAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [Parse setApplicationId:@"n7N5WY2FgddzT9GagvvgEgNFYR4u2iRjP4CkCKK3"
                  clientKey:@"YzqN7TkJitqR9N2bCyfiaHyeJ4hM8ovEOoE69le7"];
    
    [_window setBackgroundColor:[NSColor blackColor]];
    _mediaFrames = [NSMutableDictionary dictionary];
    _mediaTypes = [NSMutableDictionary dictionary];
    _playStatus = [NSMutableDictionary dictionary];
    
    _locationManager = [[CLLocationManager alloc] init];
    _locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    _locationManager.delegate = self;
    [_locationManager startUpdatingLocation];
    
    self.corner_lt = CGPointMake(0, 768);
    self.corner_rt = CGPointMake(800, 768);
    self.corner_rb = CGPointMake(800, 0);
    self.corner_lb = CGPointMake(0, 0);
    
    [ASMarkerDetector sharedDetector].delegate = self;
    
    self.anchorView0.image = [NSImage imageNamed:@"anchor0.png"];
    self.anchorView1.image = [NSImage imageNamed:@"anchor1.png"];
    self.anchorView2.image = [NSImage imageNamed:@"anchor2.png"];
    self.anchorView3.image = [NSImage imageNamed:@"anchor3.png"];
    
    [[ASMarkerDetector sharedDetector] detect];
}

#pragma mark - Marker Detection methods

- (void)detectMarkerId:(int)markerId atAbsPosition:(CGPoint)absPosition
{
    WebView *mediaView = [_mediaFrames objectForKey:@(markerId)];
    if (mediaView == nil && self.isQuerying == NO) {
        self.isQuerying = YES;
        
        
        PFQuery *query = [PFQuery queryWithClassName:@"PlayBack"];
        PFGeoPoint *geoPoint = [PFGeoPoint geoPointWithLocation:_currentLocation];
        // TODO: add more constraints (e.g. location)
        [query whereKey:@"markerId" equalTo:@(markerId)];
        [query whereKey:@"location" nearGeoPoint:geoPoint withinKilometers:THRESHOLD_DISTANCE];
        NSDate *thresholdDate = [NSDate dateWithTimeInterval:-THRESHOLD_TIME_INTERVAL sinceDate:[NSDate date]];
        
        [query whereKey:@"createdAt" greaterThan:thresholdDate];
        [query orderByDescending:@"createdAt"];
        
        
        
        [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
            if (!error) {
                if (objects.count == 0) {
                    NSLog(@"no video set");
                } else {
                    NSLog(@"media exists");
                    CGPoint p = [self positionRelativeToProjection:absPosition];
                    float ratio = [self scaleRatioOfProjection];
                    [self createDisplayForMarker:markerId WithData:objects[0] andFrame:NSMakeRect(p.x,
                                                                                                  p.y,
                                                                                                  DefaultMediaFrameSize.width * ratio,
                                                                                                  DefaultMediaFrameSize.height * ratio)];
                }
            } else {
                NSLog(@"Error: %@", error);
            }
            self.isQuerying = NO;
        }];
    } else if (mediaView != nil){
        // change location
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(destroyMediaFrameOfMarker:) object:@(markerId)];
        
        CGPoint p = [self positionRelativeToProjection:absPosition];
        float ratio = [self scaleRatioOfProjection];
        mediaView.frame = NSMakeRect(p.x, p.y, DefaultMediaFrameSize.width * ratio, DefaultMediaFrameSize.height * ratio);
        
        [self performSelector:@selector(destroyMediaFrameOfMarker:) withObject:@(markerId) afterDelay:3.5];
    }
}

#pragma mark - Content Displaying methods

- (void)showNotAssignedWarningForplayVideoForWebView:(WebView *)webView
{
    [webView.mainFrame loadHTMLString:@"NO MEDIA ASSIGNED YET!" baseURL:nil];
}

- (void)createDisplayForMarker:(int)markerId WithData:(id)data andFrame:(CGRect)frame
{
    NSLog(@"mediaId: %d", markerId);
    NSString *type = data[@"type"];
    
    WebView *mediaView = [[WebView alloc] initWithFrame:frame];
    [self.window.contentView addSubview:mediaView];
    [_mediaFrames setObject:mediaView forKey:@(markerId)];
    [_mediaTypes setObject:@(markerId) forKey:type];
    [_playStatus setObject:@(PAUSE) forKey:@(markerId)];
    
    if ([type isEqualToString:@"video"])
        [self playVideoForWebView:mediaView withVideoId:data[@"videoId"]];
    else if ([type isEqualToString:@"image"])
        [self playImageForWebView:mediaView withImageURL:data[@"imageURL"]];
    else if ([type isEqualToString:@"photo"])
        [self playImageForWebView:mediaView withImageURL:((PFFile *) data[@"photoFile"]).url];;
        
    
    [self performSelector:@selector(destroyMediaFrameOfMarker:) withObject:@(markerId) afterDelay:5];
}


- (void)playVideoForWebView:(WebView *)webView withVideoId:(NSString *)videoId
{
    NSString *ytHTML = [NSString stringWithFormat:@"\
                        <!DOCTYPE html>\
                        <html>\
                        <head>\
                        <script>\
                        function callPlayer(frame_id, func, args) {\
                        if (window.jQuery && frame_id instanceof jQuery) frame_id = frame_id.get(0).id;\
                        var iframe = document.getElementById(frame_id);\
                        if (iframe && iframe.tagName.toUpperCase() != 'IFRAME') {\
                        iframe = iframe.getElementsByTagName('iframe')[0];\
                        }\
                        if (iframe) {\
                        iframe.contentWindow.postMessage(JSON.stringify({\
                        'event': 'command',\
                        'func': func,\
                        'args': args || [],\
                        'id': frame_id\
                        }), '*');\
                        }\
                        }\
                        </script>\
                        <body>\
                        <div id='player'><iframe width='%f' height='%f' frameborder='0' title='YouTube video player' type='text/html' src='http://www.youtube.com/embed/%@?enablejsapi=1'></iframe></div>\
                        </body>\
                        </html>",
                        webView.frame.size.width, webView.frame.size.height, videoId];
    NSLog(@"%@", webView);
    [webView.mainFrame loadHTMLString:ytHTML baseURL:nil];
    [self performSelector:@selector(markerIsPressed:) withObject:@(99) afterDelay:5];
}

- (void)playImageForWebView:(WebView *)webView withImageURL:(NSString *)imageURL;
{
    NSString *ytHTML = [NSString stringWithFormat:@"\
                        <img width='%f' height='%f' frameborder='0' \
                        src='%@'></img>", webView.frame.size.width, webView.frame.size.height, imageURL];
    
    [webView.mainFrame loadHTMLString:ytHTML baseURL:nil];
}

- (void)destroyMediaFrameOfMarker:(NSNumber *)markerId
{
    WebView *mediaView = [_mediaFrames objectForKey:markerId];
    [mediaView removeFromSuperview];
    [_mediaFrames removeObjectForKey:markerId];
    [_playStatus removeObjectForKey:markerId];
}

#pragma mark - CLLocationManagerDelegate methods

- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation
{
    NSLog(@"%@", newLocation);
    NSLog(@"moving %f m", [newLocation distanceFromLocation:oldLocation]);
    _currentLocation = newLocation;
}

#pragma mark - NSWindowDelegate methods

- (void)windowWillClose:(NSNotification *)notification
{
    [NSApp terminate:self];
}


- (CGPoint)positionRelativeToProjection:(CGPoint)absPosiotn
{
    float projectionImageWidth = _corner_rt.x - _corner_lb.x;
    float projectionImageHeight = _corner_rt.y - _corner_lb.y;
    
    float x = (absPosiotn.x - self.corner_lb.x) * ProjectorResolutionWidth/projectionImageWidth;
    float y = (absPosiotn.y - self.corner_lb.y) * ProjectorResolutionHeight/projectionImageHeight;
    
    return CGPointMake(x, y);
}

// according to width
- (float)scaleRatioOfProjection
{
    return ProjectorResolutionWidth / (_corner_rt.x - _corner_lb.x);
}


- (NSRect)getFrameOfMarker:(NSNumber *)markerId
{
    WebView *mediaView = [_mediaFrames objectForKey:markerId];
    return mediaView? mediaView.frame: NSMakeRect(-1000, -1000, 0, 0);
}

- (void)markerIsPressed:(NSNumber *)markerId
{
    NSLog(@"sooooooooong laaaaaa%@", markerId);
    WebView *mediaView = [_mediaFrames objectForKey:markerId];
    
    [mediaView stringByEvaluatingJavaScriptFromString:@"callPlayer('player','playVideo');"];
//    [mediaView stringByEvaluatingJavaScriptFromString:@"callPlayer('player','pauseVideo');"];
    
}

- (BOOL)markerIsVideo:(NSNumber *)markerId
{
    return [((NSString *)[_mediaTypes objectForKey:markerId]) isEqualToString:@"video"]? YES:NO;
}

- (void)setCornerLeftTop:(CGPoint)point
{
    _corner_lt = point;
}

- (void)setCornerRightTop:(CGPoint)point;
{
    _corner_rt = point;
}

- (void)setCornerRightBottom:(CGPoint)point;
{
    _corner_rb = point;
}

- (void)setCornerLeftBottom:(CGPoint)point;
{
    _corner_lb = point;
}

@end
