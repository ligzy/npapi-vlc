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

@interface VLCNoMediaLayer : CALayer {
}

@end

@interface VLCControllerLayer : CALayer {
    CGImageRef _playImage;
    CGImageRef _pauseImage;

    CGImageRef _sliderTrackLeft;
    CGImageRef _sliderTrackRight;
    CGImageRef _sliderTrackCenter;

    CGImageRef _knob;
}
- (BOOL)_isPlaying;

@end

static CALayer * rootLayer;
static VLCNoMediaLayer * noMediaLayer;
static VLCControllerLayer * controllerLayer;

VlcPluginMac::VlcPluginMac(NPP instance, NPuint16_t mode) :
    VlcPluginBase(instance, mode)
{
    rootLayer = [[CALayer alloc] init];
}

VlcPluginMac::~VlcPluginMac()
{
    [controllerLayer release];
    [rootLayer release];
}

void VlcPluginMac::set_player_window()
{
    // XXX FIXME insert appropriate call here
}

void VlcPluginMac::toggle_fullscreen()
{
    if (!get_options().get_enable_fs())
        return;
    if (playlist_isplaying())
        libvlc_toggle_fullscreen(getMD());
}

void VlcPluginMac::set_fullscreen(int yes)
{
    if (!get_options().get_enable_fs())
        return;
    if (playlist_isplaying())
        libvlc_set_fullscreen(getMD(), yes);
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
    controllerLayer.opaque = (float)b_value;
}

bool VlcPluginMac::get_toolbar_visible()
{
    return (bool)controllerLayer.opaque;
}

void VlcPluginMac::update_controls()
{
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

    controllerLayer = [[VLCControllerLayer alloc] init];
    controllerLayer.opaque = 1.;
    [rootLayer addSublayer: controllerLayer];

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

            return true;
        }
        case NPCocoaEventMouseUp:
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

    CGImageRelease(_knob);

    [super dealloc];
}

- (BOOL)_isPlaying {
    return YES;
}

#pragma mark -
#pragma mark drawing

- (CGRect)_playPauseButtonRect
{
    return CGRectMake(4, (25 - CGImageGetHeight(_playImage)) / 2, CGImageGetWidth(_playImage), CGImageGetHeight(_playImage));
}

- (CGRect)_sliderRect
{
    CGFloat sliderYPosition = (self.bounds.size.height - CGImageGetHeight(_sliderTrackLeft)) / 2.0;
    CGFloat playPauseButtonWidth = [self _playPauseButtonRect].size.width;

    return CGRectMake(playPauseButtonWidth + 7, sliderYPosition,
                      self.bounds.size.width - playPauseButtonWidth - 10, CGImageGetHeight(_sliderTrackLeft));
}

- (CGRect)_sliderThumbRect
{
    CGRect sliderRect = [self _sliderRect];

    CGFloat fraction = 0.0;
    /*    if (_movie)
     fraction = [self _currentTime] / [self _duration];*/

    CGFloat x = fraction * (CGRectGetWidth(sliderRect) - CGImageGetWidth(_knob));

    return CGRectMake(CGRectGetMinX(sliderRect) + x, CGRectGetMinY(sliderRect) + 1,
                      CGImageGetWidth(_knob), CGImageGetHeight(_knob));
}

- (CGRect)_innerSliderRect
{
    return CGRectInset([self _sliderRect], CGRectGetWidth([self _sliderThumbRect]) / 2, 0);
}

- (void)_drawPlayPauseButtonInContext:(CGContextRef)context
{
    CGContextDrawImage(context, [self _playPauseButtonRect], _playImage); //playlist_isplaying() ? _pauseImage;
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

@end

