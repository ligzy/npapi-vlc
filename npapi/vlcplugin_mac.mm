/*****************************************************************************
 * vlcplugin_mac.cpp: a VLC plugin for Mozilla (Mac interface)
 *****************************************************************************
 * Copyright (C) 2011-2013 VLC Authors and VideoLAN
 * $Id$
 *
 * Authors: Felix Paul Kühne <fkuehne # videolan # org>
 *          Cheng Sun <chengsun9@gmail.com>
 *          Jean-Baptiste Kempf <jb@videolan.org>
 *          James Bates <james.h.bates@gmail.com>
 *          Pierre d'Herbemont <pdherbemont # videolan.org>
 *          David Fuhrmann <david dot fuhrmann at googlemail dot com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/

#include "vlcplugin_mac.h"

#include <npapi.h>

#include <QuartzCore/QuartzCore.h>
#include <AppKit/AppKit.h>

#define SHOW_BRANDING 1

@interface VLCNoMediaLayer : CALayer {
    VlcPluginMac *_cppPlugin;
}
@property (readwrite) VlcPluginMac * cppPlugin;

@end

@interface VLCBrowserRootLayer : CALayer
- (void)addVoutLayer:(CALayer *)aLayer;
- (void)removeVoutLayer:(CALayer *)aLayer;
- (CGSize)currentOutputSize;
@end

@interface VLCControllerLayer : CALayer {
    CGImageRef _playImage;
    CGImageRef _pauseImage;

    CGImageRef _sliderTrackLeft;
    CGImageRef _sliderTrackRight;
    CGImageRef _sliderTrackCenter;

    CGImageRef _enterFullscreen;
    CGImageRef _leaveFullscreen;

    CGImageRef _knob;

    BOOL _wasPlayingBeforeMouseDown;
    BOOL _isScrubbing;
    CGFloat _mouseDownXDelta;

    double _position;
    BOOL _isPlaying;
    BOOL _isFullscreen;

    VlcPluginMac *_cppPlugin;
}
@property (readwrite) double mediaPosition;
@property (readwrite) BOOL isPlaying;
@property (readwrite) BOOL isFullscreen;
@property (readwrite) VlcPluginMac * cppPlugin;

- (void)handleMouseDown:(CGPoint)point;
- (void)handleMouseUp:(CGPoint)point;
- (void)handleMouseDragged:(CGPoint)point;

@end

@interface VLCControllerLayer (Internal)
- (CGRect)_playPauseButtonRect;
- (CGRect)_fullscreenButtonRect;
- (CGRect)_sliderRect;
@end

@interface VLCFullscreenContentView : NSView {
    VlcPluginMac *_cppPlugin;
    NSTimeInterval _timeSinceLastMouseMove;
}
@property (readwrite) VlcPluginMac * cppPlugin;

@end

@interface VLCFullscreenWindow : NSWindow {
    NSRect _initialFrame;
    VLCFullscreenContentView *_customContentView;
}
@property (readonly) VLCFullscreenContentView* customContentView;

- (id)initWithContentRect:(NSRect)contentRect;

@end

@interface NSScreen (VLCAdditions)
- (BOOL)hasMenuBar;
- (BOOL)hasDock;
- (CGDirectDisplayID)displayID;
@end

static VLCBrowserRootLayer * browserRootLayer;
static CALayer * playbackLayer;
static VLCNoMediaLayer * noMediaLayer;
static VLCControllerLayer * controllerLayer;
static VLCFullscreenWindow * fullscreenWindow;
static VLCFullscreenContentView * fullscreenView;

VlcPluginMac::VlcPluginMac(NPP instance, NPuint16_t mode) :
    VlcPluginBase(instance, mode)
{
    browserRootLayer = [[VLCBrowserRootLayer alloc] init];
}

VlcPluginMac::~VlcPluginMac()
{
    [fullscreenWindow release];
    [playbackLayer release];
    [noMediaLayer release];
    [controllerLayer release];
    [browserRootLayer release];
}

void VlcPluginMac::set_player_window()
{
    /* pass base layer to libvlc to pass it on to the vout */
    libvlc_media_player_set_nsobject(getMD(), browserRootLayer);
}

void VlcPluginMac::toggle_fullscreen()
{
    if (!get_options().get_enable_fs())
        return;
    libvlc_toggle_fullscreen(getMD());
    this->update_controls();

    if (get_fullscreen() != 0) {
        if (!fullscreenWindow) {
            /* this window is kind of useless. however, we need to support 10.5, since enterFullScreenMode depends on the
             * existance of a parent window. This is solved in 10.6 and we should remove the window once we require it. */
            fullscreenWindow = [[VLCFullscreenWindow alloc] initWithContentRect: NSMakeRect(npwindow.x, npwindow.y, npwindow.width, npwindow.height)];
            [fullscreenWindow setLevel: CGShieldingWindowLevel()];
            fullscreenView = [fullscreenWindow customContentView];

            /* CAVE: the order of these methods is important, since we want a layer-hosting view instead of
             * a layer-backed view, which you'd get if you do it the other way around */
            [fullscreenView setLayer: [CALayer layer]];
            [fullscreenView setWantsLayer:YES];
            [fullscreenView setCppPlugin: this];
        }

        [noMediaLayer removeFromSuperlayer];
        [playbackLayer removeFromSuperlayer];
        [controllerLayer removeFromSuperlayer];

        [[fullscreenView layer] addSublayer: noMediaLayer];
        [[fullscreenView layer] addSublayer: playbackLayer];
        [[fullscreenView layer] addSublayer: controllerLayer];
        [[fullscreenView layer] setNeedsDisplay];

        [[fullscreenWindow contentView] enterFullScreenMode: [NSScreen mainScreen] withOptions: [NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithInt: 0], NSFullScreenModeAllScreens, nil]];
    } else {
        [[fullscreenWindow contentView] exitFullScreenModeWithOptions: nil];
        [fullscreenWindow orderOut: nil];
        [noMediaLayer removeFromSuperlayer];
        [playbackLayer removeFromSuperlayer];
        [controllerLayer removeFromSuperlayer];

        [browserRootLayer addSublayer: noMediaLayer];
        [browserRootLayer addSublayer: playbackLayer];
        [browserRootLayer addSublayer: controllerLayer];
    }
}

void VlcPluginMac::set_fullscreen(int i_value)
{
    if (!get_options().get_enable_fs())
        return;
    libvlc_set_fullscreen(getMD(), i_value);
    this->update_controls();
}

int  VlcPluginMac::get_fullscreen()
{
    return libvlc_get_fullscreen(getMD());
}

void VlcPluginMac::set_toolbar_visible(bool b_value)
{
    if (!get_options().get_show_toolbar())
        return;
    [controllerLayer setHidden: !b_value];
}

bool VlcPluginMac::get_toolbar_visible()
{
    return controllerLayer.isHidden;
}

void VlcPluginMac::update_controls()
{
    [controllerLayer setMediaPosition: libvlc_media_player_get_position(getMD())];
    [controllerLayer setIsPlaying: playlist_isplaying()];
    [controllerLayer setIsFullscreen:this->get_fullscreen()];

    libvlc_state_t currentstate = libvlc_media_player_get_state(getMD());
    if (currentstate == libvlc_Playing || currentstate == libvlc_Paused || currentstate == libvlc_Opening) {
        [noMediaLayer setHidden: YES];
        [playbackLayer setHidden: NO];
        [playbackLayer setNeedsDisplay];
    } else {
        [noMediaLayer setHidden: NO];
        [playbackLayer setHidden: YES];
    }

    [controllerLayer setNeedsDisplay];
}

bool VlcPluginMac::create_windows()
{
    return true;
}

bool VlcPluginMac::resize_windows()
{
    return true;
}

bool VlcPluginMac::destroy_windows()
{
    npwindow.window = NULL;
    return true;
}

NPError VlcPluginMac::get_root_layer(void *value)
{
    noMediaLayer = [[VLCNoMediaLayer alloc] init];
    noMediaLayer.opaque = 1.;
    [noMediaLayer setCppPlugin: this];
    [browserRootLayer addSublayer: noMediaLayer];

    controllerLayer = [[VLCControllerLayer alloc] init];
    controllerLayer.opaque = 1.;
    [browserRootLayer addSublayer: controllerLayer];
    [controllerLayer setCppPlugin: this];

    [browserRootLayer setNeedsDisplay];

    *(CALayer **)value = browserRootLayer;
    return NPERR_NO_ERROR;
}

bool VlcPluginMac::handle_event(void *event)
{
    NPCocoaEvent* cocoaEvent = (NPCocoaEvent*)event;

    if (!event)
        return false;

    NPCocoaEventType eventType = cocoaEvent->type;

    switch (eventType) {
        case NPCocoaEventMouseDown:
        {
            if (cocoaEvent->data.mouse.clickCount >= 2)
                VlcPluginMac::toggle_fullscreen();

            CGPoint point = CGPointMake(cocoaEvent->data.mouse.pluginX,
                                        // Flip the y coordinate
                                        npwindow.height - cocoaEvent->data.mouse.pluginY);
            [controllerLayer handleMouseDown:[browserRootLayer convertPoint:point toLayer:controllerLayer]];

            return true;
        }
        case NPCocoaEventMouseUp:
        {
            CGPoint point = CGPointMake(cocoaEvent->data.mouse.pluginX,
                                        // Flip the y coordinate
                                        npwindow.height - cocoaEvent->data.mouse.pluginY);

            [controllerLayer handleMouseUp:[browserRootLayer convertPoint:point toLayer:controllerLayer]];

            return true;
        }
        case NPCocoaEventMouseDragged:
        {
            CGPoint point = CGPointMake(cocoaEvent->data.mouse.pluginX,
                                        // Flip the y coordinate
                                        npwindow.height - cocoaEvent->data.mouse.pluginY);

            [controllerLayer handleMouseDragged:[browserRootLayer convertPoint:point toLayer:controllerLayer]];

            return true;
        }
        case NPCocoaEventMouseEntered:
        {
            set_toolbar_visible(true);
            return true;
        }
        case NPCocoaEventMouseExited:
        {
            set_toolbar_visible(false);
            return true;
        }
        case NPCocoaEventKeyDown:
        {
            if (cocoaEvent->data.key.keyCode == 53) {
                toggle_fullscreen();
                return true;
            } else if (cocoaEvent->data.key.keyCode == 49) {
                playlist_togglePause();
                return true;
            }
        }
        case NPCocoaEventKeyUp:
        case NPCocoaEventFocusChanged:
        case NPCocoaEventScrollWheel:
            return true;

        default:
            break;
    }

    if (eventType == NPCocoaEventDrawRect) {
        /* even though we are using the CoreAnimation drawing model
         * this can be called by the browser, especially when doing
         * screenshots.
         * Since speed isn't important in this case, we could fetch
         * fetch the current frame from libvlc and render it as an
         * image.
         * However, for sakes of simplicity, just show a black
         * rectancle for now. */
        CGContextRef cgContext = cocoaEvent->data.draw.context;
        if (!cgContext) {
            return false;
        }

        float windowWidth = npwindow.width;
        float windowHeight = npwindow.height;

        CGContextSaveGState(cgContext);

        // this context is flipped..
        CGContextTranslateCTM(cgContext, 0.0, windowHeight);
        CGContextScaleCTM(cgContext, 1., -1.);

        // draw black rectancle
        CGContextAddRect(cgContext, CGRectMake(0, 0, windowWidth, windowHeight));
        CGContextSetGrayFillColor(cgContext, 0., 1.);
        CGContextDrawPath(cgContext, kCGPathFill);

        CGContextRestoreGState(cgContext);

        return true;
    }

    return VlcPluginBase::handle_event(event);
}

@implementation VLCBrowserRootLayer

- (id)init
{
    if (self = [super init]) {
        self.needsDisplayOnBoundsChange = YES;
        self.autoresizingMask = kCALayerWidthSizable | kCALayerHeightSizable;
    }

    return self;
}

- (void)addVoutLayer:(CALayer *)aLayer
{
    [CATransaction begin];
    playbackLayer = [aLayer retain];
    playbackLayer.opaque = 1.;
    playbackLayer.hidden = NO;
    playbackLayer.bounds = noMediaLayer.bounds;
    [self insertSublayer:playbackLayer below:controllerLayer];
    [self setNeedsDisplay];
    [playbackLayer setNeedsDisplay];
    CGRect frame = playbackLayer.bounds;
    frame.origin.x = 0.;
    frame.origin.y = 0.;
    playbackLayer.frame = frame;
    [CATransaction commit];
}

- (void)removeVoutLayer:(CALayer *)aLayer
{
    [CATransaction begin];
    [aLayer removeFromSuperlayer];
    [CATransaction commit];

    if (playbackLayer == aLayer) {
        [playbackLayer release];
        playbackLayer = nil;
    }
}

- (CGSize)currentOutputSize
{
    return [browserRootLayer visibleRect].size;
}

@end

@implementation VLCNoMediaLayer
@synthesize cppPlugin = _cppPlugin;

- (id)init
{
    if (self = [super init]) {
        self.needsDisplayOnBoundsChange = YES;
        self.autoresizingMask = kCALayerWidthSizable | kCALayerHeightSizable;
    }

    return self;
}

- (void)drawInContext:(CGContextRef)cgContext
{
    float windowWidth = self.visibleRect.size.width;
    float windowHeight = self.visibleRect.size.height;

    CGContextSaveGState(cgContext);

#if SHOW_BRANDING
    // draw a gray background
    CGContextAddRect(cgContext, CGRectMake(0, 0, windowWidth, windowHeight));
    CGContextSetGrayFillColor(cgContext, .5, 1.);
    CGContextDrawPath(cgContext, kCGPathFill);

    // draw info text
    CGContextSetGrayStrokeColor(cgContext, .7, 1.);
    CGContextSetTextDrawingMode(cgContext, kCGTextFillStroke);
    CGContextSetGrayFillColor(cgContext, 1., 1.);
    CFStringRef keys[2];
    keys[0] = kCTFontAttributeName;
    keys[1] = kCTForegroundColorFromContextAttributeName;
    CFTypeRef values[2];
    values[0] = CTFontCreateWithName(CFSTR("Helvetica"),18,NULL);
    values[1] = kCFBooleanTrue;
    CFDictionaryRef stylesDict = CFDictionaryCreate(kCFAllocatorDefault,
                                                    (const void **)&keys,
                                                    (const void **)&values,
                                                    2, NULL, NULL);
    CFAttributedStringRef attRef = CFAttributedStringCreate(kCFAllocatorDefault, CFSTR("VLC Multimedia Plug-in"), stylesDict);
    CTLineRef textLine = CTLineCreateWithAttributedString(attRef);
    CGRect textRect = CTLineGetImageBounds(textLine, cgContext);
    CGContextSetTextPosition(cgContext, ((windowWidth - textRect.size.width) / 2), ((windowHeight - textRect.size.height) / 2));
    CTLineDraw(textLine, cgContext);
    CFRelease(textLine);
    CFRelease(attRef);

    // print smaller text from here
    CFRelease(stylesDict);
    values[0] = CTFontCreateWithName(CFSTR("Helvetica"),14,NULL);
    stylesDict = CFDictionaryCreate(kCFAllocatorDefault,
                                    (const void **)&keys,
                                    (const void **)&values,
                                    2, NULL, NULL);
    CGContextSetGrayFillColor(cgContext, .8, 1.);

    // draw version string
    attRef = CFAttributedStringCreate(kCFAllocatorDefault, CFStringCreateWithCString(kCFAllocatorDefault, libvlc_get_version(), kCFStringEncodingUTF8), stylesDict);
    textLine = CTLineCreateWithAttributedString(attRef);
    textRect = CTLineGetImageBounds(textLine, cgContext);
    CGContextSetTextPosition(cgContext, ((windowWidth - textRect.size.width) / 2), ((windowHeight - textRect.size.height) / 2) - 25.);
    CTLineDraw(textLine, cgContext);
    CFRelease(textLine);
    CFRelease(attRef);

    // expose drawing model
    attRef = CFAttributedStringCreate(kCFAllocatorDefault, CFSTR("windowed output mode using CoreAnimation"), stylesDict);
    textLine = CTLineCreateWithAttributedString(attRef);
    textRect = CTLineGetImageBounds(textLine, cgContext);
    CGContextSetTextPosition(cgContext, ((windowWidth - textRect.size.width) / 2), ((windowHeight - textRect.size.height) / 2) - 45.);
    CTLineDraw(textLine, cgContext);
    CFRelease(textLine);
    CFRelease(attRef);

    // expose arch
#ifdef __x86_64__
    attRef = CFAttributedStringCreate(kCFAllocatorDefault, CFSTR("Intel, 64-bit"), stylesDict);
#else
    attRef = CFAttributedStringCreate(kCFAllocatorDefault, CFSTR("Intel, 32-bit"), stylesDict);
#endif
    textLine = CTLineCreateWithAttributedString(attRef);
    textRect = CTLineGetImageBounds(textLine, cgContext);
    CGContextSetTextPosition(cgContext, ((windowWidth - textRect.size.width) / 2), ((windowHeight - textRect.size.height) / 2) - 65.);
    CTLineDraw(textLine, cgContext);
    CFRelease(textLine);
    CFRelease(attRef);
    CFRelease(stylesDict);
#else
    // draw a black rect
    CGRect rect;
    float media_width = [self cppPlugin]->m_media_width;
    float media_height = [self cppPlugin]->m_media_height;

    if (media_width == 0. || media_height == 0.)
        CGRectMake(0, 0, windowWidth, windowHeight);
    else {
        CGRect layerRect = self.bounds;
        float display_width = 0.;
        float display_height = 0.;
        float src_aspect = (float)media_width / media_height;
        float dst_aspect = (float)layerRect.size.width/layerRect.size.height;
        if ( src_aspect > dst_aspect ) {
            if( layerRect.size.width != media_width ) { //don't scale if size equal
                display_width = layerRect.size.width;
                display_height = display_width / src_aspect; // + 0.5);
            } else {
                display_width = media_width;
                display_height = media_height;
            }
        } else {
            if( layerRect.size.height != media_height ) { //don't scale if size equal
                display_height = layerRect.size.height;
                display_width = display_height * src_aspect; // + 0.5);
            } else {
                display_width = media_width;
                display_height = media_height;
            }
        }

        float left = (layerRect.size.width  - display_width)  / 2.;
        float top  = (layerRect.size.height - display_height) / 2.;
        CGRect rect = CGRectMake(left, top, display_width, display_height);
    }

    CGContextAddRect(cgContext, rect);
    CGContextSetGrayFillColor(cgContext, 0., 1.);
    CGContextDrawPath(cgContext, kCGPathFill);
#endif

    CGContextRestoreGState(cgContext);
}

@end

@implementation VLCControllerLayer

@synthesize mediaPosition = _position;
@synthesize isPlaying = _isPlaying;
@synthesize isFullscreen = _isFullscreen;
@synthesize cppPlugin = _cppPlugin;

static CGImageRef createImageNamed(NSString *name)
{
    CFURLRef url = CFBundleCopyResourceURL(CFBundleGetBundleWithIdentifier(CFSTR("com.netscape.vlc")), (CFStringRef)name, CFSTR("png"), NULL);

    if (!url)
        return NULL;

    CGImageSourceRef imageSource = CGImageSourceCreateWithURL(url, NULL);
    if (!imageSource)
        return NULL;

    CGImageRef image = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
    CFRelease(imageSource);

    return image;
}

- (id)init
{
    if (self = [super init]) {
        self.needsDisplayOnBoundsChange = YES;
        self.frame = CGRectMake(0, 0, 0, 25);
        self.autoresizingMask = kCALayerWidthSizable;

        _playImage = createImageNamed(@"Play");
        _pauseImage = createImageNamed(@"Pause");
        _sliderTrackLeft = createImageNamed(@"SliderTrackLeft");
        _sliderTrackRight = createImageNamed(@"SliderTrackRight");
        _sliderTrackCenter = createImageNamed(@"SliderTrackCenter");

        _enterFullscreen = createImageNamed(@"enter-fullscreen");
        _leaveFullscreen = createImageNamed(@"leave-fullscreen");

        _knob = createImageNamed(@"Knob");
    }

    return self;
}

- (void)dealloc
{
    CGImageRelease(_playImage);
    CGImageRelease(_pauseImage);

    CGImageRelease(_sliderTrackLeft);
    CGImageRelease(_sliderTrackRight);
    CGImageRelease(_sliderTrackCenter);

    CGImageRelease(_enterFullscreen);
    CGImageRelease(_leaveFullscreen);

    CGImageRelease(_knob);

    [super dealloc];
}

#pragma mark -
#pragma mark drawing

- (CGRect)_playPauseButtonRect
{
    return CGRectMake(4., (25. - CGImageGetHeight(_playImage)) / 2., CGImageGetWidth(_playImage), CGImageGetHeight(_playImage));
}

- (CGRect)_fullscreenButtonRect
{
    return CGRectMake( CGRectGetMaxX([self _sliderRect]), (25. - CGImageGetHeight(_enterFullscreen)) / 2., CGImageGetWidth(_enterFullscreen), CGImageGetHeight(_enterFullscreen));
}

- (CGRect)_sliderRect
{
    CGFloat sliderYPosition = (self.bounds.size.height - CGImageGetHeight(_sliderTrackLeft)) / 2.;
    CGFloat playPauseButtonWidth = [self _playPauseButtonRect].size.width;

    return CGRectMake(playPauseButtonWidth + 7, sliderYPosition,
                      self.bounds.size.width - playPauseButtonWidth - 15 - CGImageGetWidth(_enterFullscreen), CGImageGetHeight(_sliderTrackLeft));
}

- (CGRect)_sliderThumbRect
{
    CGRect sliderRect = [self _sliderRect];

    CGFloat x = self.mediaPosition * (CGRectGetWidth(sliderRect) - CGImageGetWidth(_knob));

    return CGRectMake(CGRectGetMinX(sliderRect) + x, CGRectGetMinY(sliderRect) + 1,
                      CGImageGetWidth(_knob), CGImageGetHeight(_knob));
}

- (CGRect)_innerSliderRect
{
    return CGRectInset([self _sliderRect], CGRectGetWidth([self _sliderThumbRect]) / 2, 0);
}

- (void)_drawPlayPauseButtonInContext:(CGContextRef)context
{
    CGContextDrawImage(context, [self _playPauseButtonRect], self.isPlaying ? _pauseImage : _playImage);
}

- (void)_drawSliderInContext:(CGContextRef)context
{
    // Draw the thumb
    CGRect sliderThumbRect = [self _sliderThumbRect];
    CGContextDrawImage(context, sliderThumbRect, _knob);

    CGRect sliderRect = [self _sliderRect];

    // Draw left part
    CGRect sliderLeftTrackRect = CGRectMake(CGRectGetMinX(sliderRect), CGRectGetMinY(sliderRect),
                                            CGImageGetWidth(_sliderTrackLeft), CGImageGetHeight(_sliderTrackLeft));
    CGContextDrawImage(context, sliderLeftTrackRect, _sliderTrackLeft);

    // Draw center part
    CGRect sliderCenterTrackRect = CGRectInset(sliderRect, CGImageGetWidth(_sliderTrackLeft), 0);
    CGContextDrawImage(context, sliderCenterTrackRect, _sliderTrackCenter);

    // Draw right part
    CGRect sliderRightTrackRect = CGRectMake(CGRectGetMaxX(sliderCenterTrackRect), CGRectGetMinY(sliderRect),
                                             CGImageGetWidth(_sliderTrackRight), CGImageGetHeight(_sliderTrackRight));
    CGContextDrawImage(context, sliderRightTrackRect, _sliderTrackRight);

    // Draw fullscreen button
    CGRect fullscreenButtonRect = [self _fullscreenButtonRect];
    fullscreenButtonRect.origin.x = CGRectGetMaxX(sliderRightTrackRect) + 5;
    CGContextDrawImage(context, fullscreenButtonRect, self.isFullscreen ? _leaveFullscreen : _enterFullscreen);
}

- (void)drawInContext:(CGContextRef)cgContext
{
    CGContextSaveGState(cgContext);
    CGContextSetFillColorWithColor(cgContext, CGColorGetConstantColor(kCGColorBlack));
    CGContextFillRect(cgContext, self.bounds);
    CGContextRestoreGState(cgContext);

    [self _drawPlayPauseButtonInContext:cgContext];
    [self _drawSliderInContext:cgContext];
}

#pragma mark -
#pragma mark event handling

- (void)_setNewTimeForThumbCenterX:(CGFloat)centerX
{
    CGRect innerRect = [self _innerSliderRect];

    double fraction = (centerX - CGRectGetMinX(innerRect)) / CGRectGetWidth(innerRect);
    if (fraction > 1.0)
        fraction = 1.0;
    else if (fraction < 0.0)
        fraction = 0.0;

    libvlc_media_player_set_position(self.cppPlugin->getMD(), fraction);

    [self setNeedsDisplay];
}

- (void)handleMouseDown:(CGPoint)point
{
    if (CGRectContainsPoint([self _sliderRect], point)) {
        _wasPlayingBeforeMouseDown = self.isPlaying;
        _isScrubbing = YES;

        if (CGRectContainsPoint([self _sliderThumbRect], point))
            _mouseDownXDelta = point.x - CGRectGetMidX([self _sliderThumbRect]);
        else {
            [self _setNewTimeForThumbCenterX:point.x];
            _mouseDownXDelta = 0;
        }
    }
}

- (void)handleMouseUp:(CGPoint)point
{
    if (_isScrubbing) {
        _isScrubbing = NO;
        _mouseDownXDelta = 0;

        return;
    }

    if (CGRectContainsPoint([self _playPauseButtonRect], point)) {
        self.cppPlugin->playlist_togglePause();
        return;
    }
    if (CGRectContainsPoint([self _fullscreenButtonRect], point)) {
        self.cppPlugin->toggle_fullscreen();
        return;
    }
}

- (void)handleMouseDragged:(CGPoint)point
{
    if (!_isScrubbing)
        return;

    point.x -= _mouseDownXDelta;

    [self _setNewTimeForThumbCenterX:point.x];
}

@end

@implementation NSScreen (VLCAdditions)

- (BOOL)hasMenuBar
{
    return ([self displayID] == [[[NSScreen screens] objectAtIndex:0] displayID]);
}

- (BOOL)hasDock
{
    NSRect screen_frame = [self frame];
    NSRect screen_visible_frame = [self visibleFrame];
    CGFloat f_menu_bar_thickness = [self hasMenuBar] ? [[NSStatusBar systemStatusBar] thickness] : 0.0;

    BOOL b_found_dock = NO;
    if (screen_visible_frame.size.width < screen_frame.size.width)
        b_found_dock = YES;
    else if (screen_visible_frame.size.height + f_menu_bar_thickness < screen_frame.size.height)
        b_found_dock = YES;

    return b_found_dock;
}

- (CGDirectDisplayID)displayID
{
    return (CGDirectDisplayID)[[[self deviceDescription] objectForKey: @"NSScreenNumber"] intValue];
}

@end

@implementation VLCFullscreenWindow

@synthesize customContentView = _customContentView;

- (id)initWithContentRect:(NSRect)contentRect
{
    if( self = [super initWithContentRect:contentRect styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO]) {
        _initialFrame = contentRect;
        [self setBackgroundColor:[NSColor blackColor]];
        [self setAcceptsMouseMovedEvents: YES];

        _customContentView = [[VLCFullscreenContentView alloc] initWithFrame:_initialFrame];
        [_customContentView setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
        [[self contentView] addSubview: _customContentView];
        [self setInitialFirstResponder:_customContentView];
    }
    return self;
}

- (void)dealloc
{
    [_customContentView release];
    [super dealloc];
}

- (BOOL)canBecomeKeyWindow
{
    return YES;
}

- (BOOL)canBecomeMainWindow
{
    return YES;
}

@end

@implementation VLCFullscreenContentView
@synthesize cppPlugin = _cppPlugin;

- (BOOL)acceptsFirstResponder
{
    return YES;
}

- (BOOL)canBecomeKeyView
{
    return YES;
}

- (void)keyDown:(NSEvent *)theEvent
{
    NSString * characters = [theEvent charactersIgnoringModifiers];
    unichar key = 0;

    if ([characters length] > 0) {
        key = [[characters lowercaseString] characterAtIndex: 0];
        if (key) {
            /* Escape should always get you out of fullscreen */
            if (key == (unichar) 0x1b) {
                self.cppPlugin->toggle_fullscreen();
                return;
            } else if (key == ' ') {
                self.cppPlugin->playlist_togglePause();
                return;
            }
        }
    }
    [super keyDown: theEvent];
}

- (void)mouseDown:(NSEvent *)theEvent
{
    if ([theEvent type] == NSLeftMouseDown && !([theEvent modifierFlags] & NSControlKeyMask)) {
        if ([theEvent clickCount] >= 2)
            self.cppPlugin->toggle_fullscreen();
        else {
            NSPoint point = [NSEvent mouseLocation];

            [controllerLayer handleMouseDown:[browserRootLayer convertPoint:CGPointMake(point.x, point.y) toLayer:controllerLayer]];
        }
    }

    [super mouseDown: theEvent];
}

- (void)mouseUp:(NSEvent *)theEvent
{
    NSPoint point = [NSEvent mouseLocation];

    [controllerLayer handleMouseUp:[browserRootLayer convertPoint:CGPointMake(point.x, point.y) toLayer:controllerLayer]];

    [super mouseUp: theEvent];
}

- (void)mouseDragged:(NSEvent *)theEvent
{
    NSPoint point = [NSEvent mouseLocation];

    [controllerLayer handleMouseDragged:[browserRootLayer convertPoint:CGPointMake(point.x, point.y) toLayer:controllerLayer]];

    [super mouseDragged: theEvent];
}

- (void)mouseMoved:(NSEvent *)theEvent
{
    self.cppPlugin->set_toolbar_visible(true);
    _timeSinceLastMouseMove = [NSDate timeIntervalSinceReferenceDate];
    [self performSelector:@selector(hideToolbar) withObject:nil afterDelay: 4.1];

    [super mouseMoved: theEvent];
}

- (void)hideToolbar
{
    if ([NSDate timeIntervalSinceReferenceDate] - _timeSinceLastMouseMove >= 4) {
        self.cppPlugin->set_toolbar_visible(false);
        [NSCursor setHiddenUntilMouseMoves:YES];
    }
}

@end

