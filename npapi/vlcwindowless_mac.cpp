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

    // draw a gray background
    CGContextAddRect(cgContext, CGRectMake(0, 0, windowWidth, windowHeight));
    CGContextSetRGBFillColor(cgContext,r/255.,g/255.,b/255.,1.);
    CGContextDrawPath(cgContext, kCGPathFill);

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
        if (VlcPluginBase::playlist_isplaying() && VlcPluginBase::player_has_vout())
            return false;

        CGContextRef cgContext = cocoaEvent->data.draw.context;
        if (!cgContext) {
            return false;
        }

        drawBackground(cocoaEvent);

        return true;
    }

    return VlcPluginBase::handle_event(event);
}
