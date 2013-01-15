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

@interface VLCNoMediaLayer : CALayer {
}

@end

@interface VLCPlaybackLayer : CALayer {
    VlcPluginMac *_cppPlugin;
}
@property (readwrite) VlcPluginMac * cppPlugin;

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

@interface VLCFullscreenContentView : NSView

@end

@interface VLCFullscreenWindow : NSWindow {
    NSRect initialFrame;
}

- (id)initWithContentRect:(NSRect)contentRect;

- (void)enterFullscreen;
- (void)leaveFullscreen;

@end

@interface NSScreen (VLCAdditions)
- (BOOL)hasMenuBar;
- (BOOL)hasDock;
- (CGDirectDisplayID)displayID;
@end

static CALayer * rootLayer;
static VLCPlaybackLayer * playbackLayer;
static VLCNoMediaLayer * noMediaLayer;
static VLCControllerLayer * controllerLayer;
static VLCFullscreenWindow * fullscreenWindow;

VlcPluginMac::VlcPluginMac(NPP instance, NPuint16_t mode) :
    VlcPluginBase(instance, mode)
{
    rootLayer = [[CALayer alloc] init];
}

VlcPluginMac::~VlcPluginMac()
{
    [playbackLayer release];
    [noMediaLayer release];
    [controllerLayer release];
    [rootLayer release];
}

void VlcPluginMac::set_player_window()
{
    libvlc_video_set_format_callbacks(getMD(),
                                      video_format_proxy,
                                      video_cleanup_proxy);
    libvlc_video_set_callbacks(getMD(),
                               video_lock_proxy,
                               video_unlock_proxy,
                               video_display_proxy,
                               this);
}

unsigned VlcPluginMac::video_format_cb(char *chroma,
                                       unsigned *width, unsigned *height,
                                       unsigned *pitches, unsigned *lines)
{
    if ( p_browser ) {
        float src_aspect = (float)(*width) / (*height);
        float dst_aspect = (float)npwindow.width/npwindow.height;
        if ( src_aspect > dst_aspect ) {
            if( npwindow.width != (*width) ) { //don't scale if size equal
                (*width) = npwindow.width;
                (*height) = static_cast<unsigned>( (*width) / src_aspect + 0.5);
            }
        }
        else {
            if( npwindow.height != (*height) ) { //don't scale if size equal
                (*height) = npwindow.height;
                (*width) = static_cast<unsigned>( (*height) * src_aspect + 0.5);
            }
        }
    }

    m_media_width = (*width);
    m_media_height = (*height);

    memcpy(chroma, "RGBA", sizeof("RGBA")-1);
    (*pitches) = m_media_width * 4;
    (*lines) = m_media_height;

    //+1 for vlc 2.0.3/2.1 bug workaround.
    //They writes after buffer end boundary by some reason unknown to me...
    m_frame_buf.resize( (*pitches) * ((*lines)+1) );

    return 1;
}

void VlcPluginMac::video_cleanup_cb()
{
    m_frame_buf.resize(0);
    m_media_width = 0;
    m_media_height = 0;
}

void* VlcPluginMac::video_lock_cb(void **planes)
{
    (*planes) = m_frame_buf.empty()? 0 : &m_frame_buf[0];
    return 0;
}

void VlcPluginMac::video_unlock_cb(void* /*picture*/, void *const * /*planes*/)
{
}

void VlcPluginMac::video_display_cb(void * /*picture*/)
{
    [playbackLayer performSelectorOnMainThread:@selector(setNeedsDisplay) withObject: nil waitUntilDone:NO];
}

void VlcPluginMac::toggle_fullscreen()
{
    if (!get_options().get_enable_fs())
        return;
    if (playlist_isplaying())
        libvlc_toggle_fullscreen(getMD());
    this->update_controls();
}

void VlcPluginMac::set_fullscreen(int i_value)
{
    if (!get_options().get_enable_fs())
        return;
    if (playlist_isplaying())
        libvlc_set_fullscreen(getMD(), i_value);
    this->update_controls();
}

int  VlcPluginMac::get_fullscreen()
{
    int r = 0;
    if (playlist_isplaying())
        r = libvlc_get_fullscreen(getMD());
    return r;
}

void VlcPluginMac::set_toolbar_visible(bool b_value)
{
    [controllerLayer setHidden: !b_value];
}

bool VlcPluginMac::get_toolbar_visible()
{
    return (bool)controllerLayer.opaque;
}

void VlcPluginMac::update_controls()
{
    [controllerLayer setMediaPosition: libvlc_media_player_get_position(getMD())];
    [controllerLayer setIsPlaying: playlist_isplaying()];
    [controllerLayer setIsFullscreen:this->get_fullscreen()];

    if (player_has_vout()) {
        [noMediaLayer setHidden: YES];
        [playbackLayer setHidden: NO];
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
    [rootLayer addSublayer: noMediaLayer];

    playbackLayer = [[VLCPlaybackLayer alloc] init];
    playbackLayer.opaque = 1.;
    [rootLayer addSublayer: playbackLayer];
    [playbackLayer setCppPlugin: this];
    [playbackLayer setHidden: YES];

    controllerLayer = [[VLCControllerLayer alloc] init];
    controllerLayer.opaque = 1.;
    [rootLayer addSublayer: controllerLayer];
    [controllerLayer setCppPlugin: this];

    *(CALayer **)value = rootLayer;
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
            [controllerLayer handleMouseDown:[rootLayer convertPoint:point toLayer:controllerLayer]];

            return true;
        }
        case NPCocoaEventMouseUp:
        {
            CGPoint point = CGPointMake(cocoaEvent->data.mouse.pluginX,
                                        // Flip the y coordinate
                                        npwindow.height - cocoaEvent->data.mouse.pluginY);

            [controllerLayer handleMouseUp:[rootLayer convertPoint:point toLayer:controllerLayer]];

            return true;
        }
        case NPCocoaEventMouseDragged:
        {
            CGPoint point = CGPointMake(cocoaEvent->data.mouse.pluginX,
                                        // Flip the y coordinate
                                        npwindow.height - cocoaEvent->data.mouse.pluginY);

            [controllerLayer handleMouseDragged:[rootLayer convertPoint:point toLayer:controllerLayer]];

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
        case NPCocoaEventKeyUp:
        case NPCocoaEventKeyDown:
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

@implementation VLCPlaybackLayer
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
    if (!cgContext)
        return;

    if (![self cppPlugin]->playlist_isplaying() || ![self cppPlugin]->player_has_vout())
        return;

    unsigned int media_width = [self cppPlugin]->m_media_width;
    unsigned int media_height = [self cppPlugin]->m_media_height;

    if (media_width == 0 || media_height == 0)
        return;

    CGContextSaveGState(cgContext);

    /* Compute the position of the video */
    CGSize layerSize = [self preferredFrameSize];
    float left = (layerSize.width  - media_width)  / 2.;
    float top  = (layerSize.height - media_height) / 2.;
    static const size_t kComponentsPerPixel = 4;
    static const size_t kBitsPerComponent = sizeof(unsigned char) * 8;

    /* render frame */
    CFDataRef dataRef = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault,
                                                    (const uint8_t *)&[self cppPlugin]->m_frame_buf[0],
                                                    sizeof([self cppPlugin]->m_frame_buf[0]),
                                                    kCFAllocatorNull);
    CGDataProviderRef dataProvider = CGDataProviderCreateWithCFData(dataRef);
    CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
    CGImageRef image = CGImageCreate(media_width,
                                     media_height,
                                     kBitsPerComponent,
                                     kBitsPerComponent * kComponentsPerPixel,
                                     kComponentsPerPixel * media_width,
                                     colorspace,
                                     kCGBitmapByteOrder16Big,
                                     dataProvider,
                                     NULL,
                                     true,
                                     kCGRenderingIntentPerceptual);
    if (!image) {
        CGColorSpaceRelease(colorspace);
        CGImageRelease(image);
        CGDataProviderRelease(dataProvider);
        CGContextRestoreGState(cgContext);
        return;
    }
    CGRect rect = CGRectMake(left, top, media_width, media_height);
    CGContextDrawImage(cgContext, rect, image);

    CGColorSpaceRelease(colorspace);
    CGImageRelease(image);
    CGDataProviderRelease(dataProvider);

    CGContextRestoreGState(cgContext);
}

@end

@implementation VLCNoMediaLayer

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
    CFRelease(stylesDict);

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

- (id)initWithContentRect:(NSRect)contentRect
{
    if( self = [super initWithContentRect:contentRect styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO]) {
        initialFrame = contentRect;
        [self setBackgroundColor:[NSColor blackColor]];
        [self setHasShadow:YES];
        [self setMovableByWindowBackground: YES];
        [self center];
    }
    return self;
}

- (void)enterFullscreen
{
    NSScreen *screen = [self screen];

    initialFrame = [self frame];
    [self setFrame:[[self screen] frame] display:YES animate:YES];

    NSApplicationPresentationOptions presentationOpts = [NSApp presentationOptions];
    if ([screen hasMenuBar])
        presentationOpts |= NSApplicationPresentationAutoHideMenuBar;
    if ([screen hasMenuBar] || [screen hasDock])
        presentationOpts |= NSApplicationPresentationAutoHideDock;
    [NSApp setPresentationOptions:presentationOpts];
}

- (void)leaveFullscreen
{
    [NSApp setPresentationOptions: NSApplicationPresentationDefault];
    [self setFrame:initialFrame display:YES animate:YES];
}

@end

