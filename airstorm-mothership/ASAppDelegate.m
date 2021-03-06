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

#define THRESHOLD_DISTANCE 1.0
#define THRESHOLD_TIME_INTERVAL 10800

@implementation ASAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [Parse setApplicationId:@"n7N5WY2FgddzT9GagvvgEgNFYR4u2iRjP4CkCKK3"
                  clientKey:@"YzqN7TkJitqR9N2bCyfiaHyeJ4hM8ovEOoE69le7"];
    
    _isQuerying = _isPressing = _isPreparingToHideAnchor = NO;
    
    [_window setBackgroundColor:[NSColor blackColor]];
    _mediaFrames = [NSMutableDictionary dictionary];
    _mediaTypes = [NSMutableDictionary dictionary];
    _playStatus = [NSMutableDictionary dictionary];
    
    _locationManager = [[CLLocationManager alloc] init];
    _locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    _locationManager.delegate = self;
    [_locationManager startUpdatingLocation];
    
    self.corner_lt = CGPointMake(100, 700);
    self.corner_rt = CGPointMake(900, 700);
    self.corner_rb = CGPointMake(900, 50);
    self.corner_lb = CGPointMake(100, 50);
    
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
//        PFGeoPoint *geoPoint = [PFGeoPoint geoPointWithLocation:_currentLocation];
        // TODO: add more constraints (e.g. location)
        [query whereKey:@"markerId" equalTo:@(markerId)];
//        [query whereKey:@"location" nearGeoPoint:geoPoint withinKilometers:THRESHOLD_DISTANCE];
//        NSDate *thresholdDate = [NSDate dateWithTimeInterval:-THRESHOLD_TIME_INTERVAL sinceDate:[NSDate date]];
//        
//        [query whereKey:@"createdAt" greaterThan:thresholdDate];
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
    [_mediaTypes setObject:type forKey:@(markerId)];
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
    [_mediaTypes removeObjectForKey:markerId];
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
    
    float x = (absPosiotn.x - self.corner_lb.x) * ProjectorResolutionWidth / projectionImageWidth;
    float y = (absPosiotn.y - self.corner_lb.y) * ProjectorResolutionHeight / projectionImageHeight;
    
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
    if (_isPressing) return;
    _isPressing = YES;
    
    WebView *mediaView = [_mediaFrames objectForKey:markerId];
    
    if ([[_playStatus objectForKey:markerId] isEqual:@(PAUSE)] ) {
        [mediaView stringByEvaluatingJavaScriptFromString:@"callPlayer('player','playVideo');"];
        [_playStatus setObject:@(PLAY) forKey:markerId];
        [self performSelector:@selector(setIsPressing:) withObject:NO afterDelay:1];
    }
    else {
        [mediaView stringByEvaluatingJavaScriptFromString:@"callPlayer('player','pauseVideo');"];
        [_playStatus setObject:@(PAUSE) forKey:markerId];
        [self performSelector:@selector(setIsPressing:) withObject:NO afterDelay:1];
    }
    
}

- (BOOL)markerIsVideo:(NSNumber *)markerId
{
    NSString *type = [_mediaTypes objectForKey:markerId];
    return [type isEqualToString:@"video"];
}

- (void)setCornerLeftTopWithMarkerCenter:(CGPoint)center andOffset:(CGPoint)offset
{
    if (ABS(center.x - _corner_lt.y) > offset.x * 1.5 || ABS(center.y - _corner_lt.y) > offset.y * 1.5) {
//        [self stopHideAnchor];
    }
    _corner_lt = CGPointMake(center.x - offset.x, center.y + offset.y);
//    _corner_lt = center;
}

- (void)setCornerRightTopWithMarkerCenter:(CGPoint)center andOffset:(CGPoint)offset
{
    if (ABS(center.x - _corner_rt.y) > offset.x * 1.5 || ABS(center.y - _corner_rt.y) > offset.y * 1.5) {
//        [self stopHideAnchor];
    }
    _corner_rt = CGPointMake(center.x + offset.x, center.y + offset.y);
//    _corner_rt = center;
}

- (void)setCornerRightBottomWithMarkerCenter:(CGPoint)center andOffset:(CGPoint)offset
{
    if (ABS(center.x - _corner_rb.y) > offset.x * 1.5 || ABS(center.y - _corner_rb.y) > offset.y * 1.5) {
//        [self stopHideAnchor];
    }
    _corner_rb = CGPointMake(center.x + offset.x, center.y - offset.y);
//    _corner_rb = center;
}

- (void)setCornerLeftBottomWithMarkerCenter:(CGPoint)center andOffset:(CGPoint)offset;
{
    if (ABS(center.x - _corner_lb.y) > offset.x * 1.5 || ABS(center.y - _corner_lb.y) > offset.y * 1.5) {
//        [self stopHideAnchor];
    }
    _corner_lb = CGPointMake(center.x - offset.x, center.y - offset.y);
//    _corner_lb = center;
}

- (void)stopHideAnchor
{
    if (_anchorView0.isHidden) return;
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideAllAnchor) object:nil];
    _isPreparingToHideAnchor = NO;
}

- (void)prepareToHideAnchor
{
    if (_isPreparingToHideAnchor) return;
    else {
        [self performSelector:@selector(hideAllAnchor) withObject:nil afterDelay:3];
        _isPreparingToHideAnchor = YES;
    }
}

- (void)hideAllAnchor
{
    [_anchorView0 setHidden:YES];
    [_anchorView1 setHidden:YES];
    [_anchorView2 setHidden:YES];
    [_anchorView3 setHidden:YES];
}

- (void)resetAnchor
{
    [_anchorView0 setHidden:NO];
    [_anchorView1 setHidden:NO];
    [_anchorView2 setHidden:NO];
    [_anchorView3 setHidden:NO];
    _isPreparingToHideAnchor = NO;
}

@end
