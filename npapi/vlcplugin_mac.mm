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

@interface VLCControllerLayer : CALayer {
    BOOL b_nomedia;
}
@property (readwrite) BOOL noMedia;

@end

static CALayer * rootLayer;
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
    controllerLayer = [[VLCControllerLayer alloc] init];
    controllerLayer.opaque = 1.;
    controllerLayer.autoresizingMask = kCALayerWidthSizable | kCALayerHeightSizable;
    [controllerLayer setNoMedia:YES];

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

@implementation VLCControllerLayer
@synthesize noMedia=b_nomedia;

- (id)init
{
    if (self = [super init]) {
        self.needsDisplayOnBoundsChange = YES;
        self.frame = CGRectMake(0, 0, 0, 25);
        self.autoresizingMask = kCALayerWidthSizable;
    }

    return self;
}

- (void)drawNoMedia:(CGContextRef)cgContext
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

- (void)drawInContext:(CGContextRef)cgContext
{
    if (self.noMedia)
        [self drawNoMedia:cgContext];
    else {
        CGContextSaveGState(cgContext);
        CGContextSetFillColorWithColor(cgContext, CGColorGetConstantColor(kCGColorBlack));
        CGContextFillRect(cgContext, self.bounds);
        CGContextRestoreGState(cgContext);
    }
}

@end
