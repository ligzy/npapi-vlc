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

VlcPluginMac::VlcPluginMac(NPP instance, NPuint16_t mode) :
    VlcPluginBase(instance, mode)
{
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
    /* as MacOS X video output is windowless, set viewport */
    libvlc_rectangle_t view, clip;

    /* browser sets port origin to top-left location of plugin
     * relative to GrafPort window origin is set relative to document,
     * which of little use for drawing
     */
    view.top	= 0; // ((NP_Port*) (npwindow.window))->porty;
    view.left	= 0; // ((NP_Port*) (npwindow.window))->portx;
    view.bottom  = npwindow.height+view.top;
    view.right   = npwindow.width+view.left;

    /* clipRect coordinates are also relative to GrafPort */
    clip.top     = npwindow.clipRect.top;
    clip.left    = npwindow.clipRect.left;
    clip.bottom  = npwindow.clipRect.bottom;
    clip.right   = npwindow.clipRect.right;

#ifdef NOT_WORKING
    libvlc_video_set_viewport(p_vlc, p_plugin->getMD(), &view, &clip);
#else
#warning disabled code
#endif
    return true;
}

bool VlcPluginMac::destroy_windows()
{
    npwindow.window = NULL;
    return true;
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
