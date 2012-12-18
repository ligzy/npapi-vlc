/*****************************************************************************
 * vlcwindowless_X11.cpp: a VLC plugin for Mozilla (X11 windowless)
 *****************************************************************************
 * Copyright © 2012 VideoLAN
 * $Id$
 *
 * Authors: Cheng Sun <chengsun9@gmail.com>
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

#include "vlcwindowless_X11.h"

#include <cstring>
#include <cstdlib>

VlcWindowlessX11::VlcWindowlessX11(NPP instance, NPuint16_t mode) :
    VlcWindowlessBase(instance, mode)
{
}

bool VlcWindowlessX11::handle_event(void *event)
{
#warning FIXME: this is waaayyy too slow!
    XEvent *xevent = static_cast<XEvent *>(event);
    switch (xevent->type) {
    case GraphicsExpose:
        XGraphicsExposeEvent *xgeevent = reinterpret_cast<XGraphicsExposeEvent *>(xevent);
        Display *display = xgeevent->display;

        int screen = XDefaultScreen(display);
        XVisualInfo visual;
        XMatchVisualInfo(display, screen, 24, TrueColor, &visual);
        XImage *image = XCreateImage(display, visual.visual, 24, ZPixmap,
                                    0, &m_frame_buf[0],
                                    m_media_width, m_media_height,
                                    DEF_PIXEL_BYTES*8,
                                    m_media_width * DEF_PIXEL_BYTES);

        const NPRect &clip = npwindow.clipRect;
        XPutImage(display, xgeevent->drawable,
                  XDefaultGCOfScreen(XScreenOfDisplay(display, screen)), image,
                  clip.left - npwindow.x, clip.top - npwindow.y,
                  clip.left, clip.top,
                  clip.right - clip.left, clip.bottom - clip.top);
        XFree(image);

        return true;
    }
    return VlcWindowlessBase::handle_event(event);
}
