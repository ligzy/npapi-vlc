/*****************************************************************************
 * vlcplugin_mac.h: a VLC plugin for Mozilla (Mac interface)
 *****************************************************************************
 * Copyright (C) 2011-2013 VLC authors and VideoLAN
 * $Id$
 *
 * Authors: Felix Paul Kühne <fkuehne # videolan # org>
 *          Cheng Sun <chengsun9@gmail.com>
 *          Jean-Baptiste Kempf <jb@videolan.org>
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

#ifndef __VLCPLUGIN_MAC_H__
#define __VLCPLUGIN_MAC_H__

#include "vlcplugin_base.h"

class VlcPluginMac : public VlcPluginBase
{
public:
    VlcPluginMac(NPP, NPuint16_t);

    int                 setSize(unsigned width, unsigned height);

    void toggle_fullscreen();
    void set_fullscreen( int );
    int  get_fullscreen();

    bool create_windows();
    bool resize_windows();
    bool destroy_windows();

    void set_toolbar_visible(bool)  { /* STUB */ }
    bool get_toolbar_visible()  { return false; }
    void update_controls()      {/* STUB */}
    void popup_menu()           {/* STUB */}

    virtual bool handle_event(void *event);
private:
    void set_player_window();

    unsigned int     i_width, i_height;

    int i_last_position;
};

#endif /* __VLCPLUGIN_MAC_H__ */
