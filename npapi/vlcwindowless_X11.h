/*****************************************************************************
 * vlcwindowless_X11.h: a VLC plugin for Mozilla (X11 windowless)
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

#ifndef __VLCWINDOWLESS_X11_H__
#define __VLCWINDOWLESS_X11_H__

#define WINDOWLESS
#include "vlcplugin_base.h"

class VlcWindowlessX11 : public VlcWindowlessBase
{
public:
    VlcWindowlessX11(NPP instance, NPuint16_t mode);

    bool handle_event(void *event);
};


#endif /* __VLCWINDOWLESS_X11_H__ */
