/*****************************************************************************
 * vlcwindowsless_mac.h: VLC NPAPI windowless plugin for Mac
 *****************************************************************************
 * Copyright (C) 2012-2013 VLC Authors and VideoLAN
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

#ifndef __VLCWINDOWLESS_MAC_H__
#define __VLCWINDOWLESS_MAC_H__

#include "vlcwindowless_base.h"

class VlcWindowlessMac : public VlcWindowlessBase
{
public:
    VlcWindowlessMac(NPP instance, NPuint16_t mode);
    virtual ~VlcWindowlessMac();

    bool handle_event(void *event);
    NPError get_root_layer(void *value);

protected:
    void drawNoPlayback(CGContextRef cgContext);

private:
    CGColorSpaceRef colorspace;
};

#endif /* __VLCWINDOWLESS_MAC_H__ */
