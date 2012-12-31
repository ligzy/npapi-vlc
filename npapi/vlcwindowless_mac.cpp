/*****************************************************************************
 * vlcwindowless_mac.cpp: VLC NPAPI windowless plugin for Mac
 *****************************************************************************
 * Copyright (C) 2012 VLC Authors and VideoLAN
 * $Id$
 *
 * Authors: Felix Paul Kühne <fkuehne # videolan # org>
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

#include <npapi.h>
#include "vlcwindowless_mac.h"

VlcWindowlessMac::VlcWindowlessMac(NPP instance, NPuint16_t mode) :
    VlcWindowlessBase(instance, mode)
{
    // get first screen
    printf("should init\n");
}

VlcWindowlessMac::~VlcWindowlessMac()
{

}

void VlcWindowlessMac::drawBackground(NPCocoaEvent *cocoaEvent)
{
    CGContextRef cgContext = cocoaEvent->data.draw.context;
    if (!cgContext)
        return;

    float windowWidth = npwindow.width;
    float windowHeight = npwindow.height;

    CGContextSaveGState(cgContext);

    // this context is flipped..
    CGContextTranslateCTM(cgContext, 0.0, windowHeight);
    CGContextScaleCTM(cgContext, 1., -1.);

    // fetch background color
    unsigned r = 0, g = 0, b = 0;
    HTMLColor2RGB(get_options().get_bg_color().c_str(), &r, &g, &b);

    // draw background
    CGContextAddRect(cgContext, CGRectMake(0, 0, windowWidth, windowHeight));
    CGContextSetRGBFillColor(cgContext,r/255.,g/255.,b/255.,1.);
    CGContextDrawPath(cgContext, kCGPathFill);

    CGContextRestoreGState(cgContext);
}

void VlcWindowlessMac::drawNoPlayback(CGContextRef cgContext)
{
    float windowWidth = npwindow.width;
    float windowHeight = npwindow.height;

    CGContextSaveGState(cgContext);

    // this context is flipped..
    CGContextTranslateCTM(cgContext, 0.0, windowHeight);
    CGContextScaleCTM(cgContext, 1., -1.);

    // draw a gray background
    CGContextAddRect(cgContext, CGRectMake(0, 0, windowWidth, windowHeight));
    CGContextSetGrayFillColor(cgContext, 0.5, 1.);
    CGContextDrawPath(cgContext, kCGPathFill);

    // draw info text
    CGContextSetRGBStrokeColor(cgContext, 0, 0, 0, .5);
    CGContextSetTextDrawingMode(cgContext, kCGTextFillStroke);
    CFStringRef keys[] = { kCTFontAttributeName };
    CFTypeRef values[] = { CTFontCreateWithName(CFSTR("Helvetica"),16,NULL) };
    CFDictionaryRef stylesDict = CFDictionaryCreate(kCFAllocatorDefault,
                                                    (const void **)&keys,
                                                    (const void **)&values,
                                                    1, NULL, NULL);
    CFAttributedStringRef attRef = CFAttributedStringCreate(kCFAllocatorDefault, CFSTR("VLC Web Plugin"), stylesDict);
    CTLineRef textTine = CTLineCreateWithAttributedString(attRef);
    CGRect textRect = CTLineGetImageBounds(textTine, cgContext);
    CGContextSetTextPosition(cgContext, ((windowWidth - textRect.size.width) / 2), ((windowHeight - textRect.size.height) / 2));
    CTLineDraw(textTine, cgContext);
    CFRelease(textTine);

    CGContextRestoreGState(cgContext);
}

bool VlcWindowlessMac::handle_event(void *event)
{
    NPCocoaEvent* cocoaEvent = (NPCocoaEvent*)event;

    if (!event)
        return false;

    NPCocoaEventType eventType = cocoaEvent->type;

    switch (eventType) {
        case NPCocoaEventMouseDown:
        {
            if (cocoaEvent->data.mouse.clickCount >= 2)
                VlcWindowlessBase::toggle_fullscreen();

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
        CGContextRef cgContext = cocoaEvent->data.draw.context;
        if (!cgContext) {
            return false;
        }

        if (!VlcPluginBase::playlist_isplaying()) {
            drawNoPlayback(cgContext);
            return true;
        }

        drawBackground(cocoaEvent);

        if(!VlcPluginBase::player_has_vout())
            return true;

        if (m_media_width == 0 || m_media_height == 0)
            return true;

        CGContextSaveGState(cgContext);

        /* context is flipped */
        CGContextTranslateCTM(cgContext, 0.0, npwindow.height);
        CGContextScaleCTM(cgContext, 1., -1.);

        /* Compute the position of the video */
        float left = (npwindow.width  - m_media_width)  / 2.;
        float top  = (npwindow.height - m_media_height) / 2.;
        static const size_t kComponentsPerPixel = 4;
        static const size_t kBitsPerComponent = sizeof(unsigned char) * 8;


        /* render frame */
        CFDataRef dataRef = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault,
                                                          (const uint8_t *)&m_frame_buf[0],
                                                          sizeof(m_frame_buf[0]),
                                                          kCFAllocatorNull);
        CGDataProviderRef dataProvider = CGDataProviderCreateWithCFData(dataRef);
        CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
        CGImageRef image = CGImageCreate(m_media_width,
                                         m_media_height,
                                         kBitsPerComponent,
                                         kBitsPerComponent * kComponentsPerPixel,
                                         kComponentsPerPixel * m_media_width,
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
            return true;
        }
        CGRect rect = CGRectMake(left, top, m_media_width, m_media_height);
        CGContextDrawImage(cgContext, rect, image);

        CGColorSpaceRelease(colorspace);
        CGImageRelease(image);
        CGDataProviderRelease(dataProvider);

        CGContextRestoreGState(cgContext);

        return true;
    }

    return VlcPluginBase::handle_event(event);
}
