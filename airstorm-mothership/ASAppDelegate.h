//
//  ASAppDelegate.h
//  airstorm-mothership
//
//  Created by Acsa Lu on 6/21/13.
//  Copyright (c) 2013 com.nmlab-g7. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface ASAppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSTextField *markerId;
@property (weak) IBOutlet WebView *webView;

- (IBAction)runButtonPressed:(id)sender;


- (void)detectMarkerId:(int)markerId;
- (void)playVideoForWebView:(WebView *)webView withVideoId:(NSString *)videoId;
- (void)showNotAssignedWarningForplayVideoForWebView:(WebView *)webView;
- (void)createDisplayWithFrame:(CGRect)frame;

@end
