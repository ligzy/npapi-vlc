/*****************************************************************************
 * npmac.cpp: Safari/Mozilla/Firefox plugin for VLC
 *****************************************************************************
 * Copyright (C) 2009, Jean-Paul Saman <jpsaman@videolan.org>
 * Copyright (C) 2012-2013 Felix Paul Kühne <fkuehne # videolan # org>
 * $Id:$
 *
 * Authors: Jean-Paul Saman <jpsaman@videolan.org>
 *          Felix Paul Kühne <fkuehne # videolan # org>
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <string.h>
#include <stddef.h>
#include <cstring>

#include "../common.h"
#include "../vlcplugin.h"
#include "../vlcshell.h"

#include <npapi.h>
#include "npfunctions.h"
#define CALL_NPN(unused, FN, ...) ((*FN)(__VA_ARGS__))



#pragma mark -
#pragma mark Globals

NPNetscapeFuncs  *gNetscapeFuncs;    /* Netscape Function table */
short               gResFile;           // Refnum of the plugin’s resource file
static inline int getMinorVersion() { return gNetscapeFuncs->version & 0xFF; }


#pragma mark -
#pragma mark Wrapper Functions


void NPN_PluginThreadAsyncCall(NPP instance, void (*func)(void *), void *userData)
{
    CALL_NPN(CallNPN_PluginThreadAsyncCallProc, gNetscapeFuncs->pluginthreadasynccall, instance, func, userData);
}




#pragma mark -
#pragma mark Private Functions

/***********************************************************************
 *
 * Wrapper functions : Netscape Navigator -> plugin
 *
 * These functions let the plugin developer just create the APIs
 * as documented and defined in npapi.h, without needing to 
 * install those functions in the function table or worry about
 * setting up globals for 68K plugins.
 *
 ***********************************************************************/

/* Function prototypes */
NPError Private_New(NPMIMEType pluginType, NPP instance, uint16_t mode,
        int16_t argc, char* argn[], char* argv[], NPSavedData* saved);
NPError Private_Destroy(NPP instance, NPSavedData** save);
NPError Private_NewStream(NPP instance, NPMIMEType type, NPStream* stream,
                          NPBool seekable, uint16_t* stype);
int32_t Private_WriteReady(NPP instance, NPStream* stream);
int32_t Private_Write(NPP instance, NPStream* stream, int32_t offset, int32_t len, void* buffer);
void    Private_StreamAsFile(NPP instance, NPStream* stream, const char* fname);
NPError Private_DestroyStream(NPP instance, NPStream* stream, NPError reason);
void    Private_Print(NPP instance, NPPrint* platformPrint);
void    Private_URLNotify(NPP instance, const char* url, NPReason reason, void* notifyData);
int16_t Private_HandleEvent(NPP instance, void* event);
NPError Private_GetValue(NPP instance, NPPVariable variable, void *r_value);
NPError Private_SetValue(NPP instance, NPNVariable variable, void *r_value);
NPError Private_SetWindow(NPP instance, NPWindow* window);

NPError  Private_Initialize(void);
void     Private_Shutdown(void);


NPError
Private_Initialize(void)
{
    NPError err;
    err = NPP_Initialize();
    return err;
}

void Private_Shutdown(void)
{
    NPP_Shutdown();
}

static bool boolValue(const char *value) {
    return ( !strcmp(value, "1") ||
            !strcasecmp(value, "true") ||
            !strcasecmp(value, "yes") );
}

/* function implementations */
NPError
Private_New(NPMIMEType pluginType, NPP instance, uint16_t mode,
        int16_t argc, char* argn[], char* argv[], NPSavedData* saved)
{
    /* find out, if the plugin should run in windowless mode.
     * if yes, choose the CoreGraphics drawing model */
    bool windowless = false;
    for( int i = 0; i < argc; i++ )
    {
        if( !strcmp( argn[i], "windowless" ) )
        {
            windowless = boolValue(argv[i]);
            break;
        }
    }

    NPError err;
    if (windowless) {
        fprintf(stderr, "running in windowless\n");
        NPBool supportsCoreGraphics = FALSE;
        err = NPN_GetValue(instance, NPNVsupportsCoreGraphicsBool, &supportsCoreGraphics);
        if (err != NPERR_NO_ERROR || !supportsCoreGraphics) {
            fprintf(stderr, "Error in New: browser doesn't support CoreGraphics drawing model\n");
            return NPERR_INCOMPATIBLE_VERSION_ERROR;
        }

        err = NPN_SetValue(instance, NPPVpluginDrawingModel, (void*)NPDrawingModelCoreGraphics);
        if (err != NPERR_NO_ERROR) {
            fprintf(stderr, "Error in New: couldn't activate CoreGraphics drawing model\n");
            return NPERR_INCOMPATIBLE_VERSION_ERROR;
        }
    } else {
        fprintf(stderr, "running windowed\n");
        NPBool supportsCoreAnimation = FALSE;
        err = NPN_GetValue(instance, NPNVsupportsCoreAnimationBool, &supportsCoreAnimation);
        if (err != NPERR_NO_ERROR || !supportsCoreAnimation) {
            fprintf(stderr, "Error in New: browser doesn't support CoreAnimation drawing model\n");
            return NPERR_INCOMPATIBLE_VERSION_ERROR;
        }

        err = NPN_SetValue(instance, NPPVpluginDrawingModel, (void*)NPDrawingModelCoreAnimation);
        if (err != NPERR_NO_ERROR) {
            fprintf(stderr, "Error in New: couldn't activate CoreAnimation drawing model\n");
            return NPERR_INCOMPATIBLE_VERSION_ERROR;
        }
    }

    NPBool supportsCocoaEvents = FALSE;
    err = NPN_GetValue(instance, NPNVsupportsCocoaBool, &supportsCocoaEvents);
    if (err != NPERR_NO_ERROR || !supportsCocoaEvents) {
        fprintf(stderr, "Error in New: browser doesn't support Cocoa event model\n");
        return NPERR_INCOMPATIBLE_VERSION_ERROR;
    }

    err = NPN_SetValue(instance, NPPVpluginEventModel, (void*)NPEventModelCocoa);
    if (err != NPERR_NO_ERROR) {
        fprintf(stderr, "Error in New: couldn't activate Cocoa event model\n");
        return NPERR_INCOMPATIBLE_VERSION_ERROR;
    }

    NPError ret = NPP_New(pluginType, instance, mode, argc, argn, argv, saved);

    return ret;
}

NPError
Private_Destroy(NPP instance, NPSavedData** save)
{
    PLUGINDEBUGSTR("Destroy");
    return NPP_Destroy(instance, save);
}

NPError
Private_SetWindow(NPP instance, NPWindow* window)
{
    NPError err;
    PLUGINDEBUGSTR("SetWindow");
    err = NPP_SetWindow(instance, window);
    return err;
}

NPError
Private_GetValue(NPP instance, NPPVariable variable, void *r_value)
{
    PLUGINDEBUGSTR("GetValue");
    return NPP_GetValue(instance, variable, r_value);
}

NPError
Private_SetValue(NPP instance, NPNVariable variable, void *r_value)
{
    PLUGINDEBUGSTR("SetValue");
    return NPP_SetValue(instance, variable, r_value);
}

NPError
Private_NewStream(NPP instance, NPMIMEType type, NPStream* stream,
            NPBool seekable, uint16_t* stype)
{
    NPError err;
    PLUGINDEBUGSTR("NewStream");
    err = NPP_NewStream(instance, type, stream, seekable, stype);
    return err;
}

int32_t
Private_WriteReady(NPP instance, NPStream* stream)
{
    int32_t result;
    PLUGINDEBUGSTR("WriteReady");
    result = NPP_WriteReady(instance, stream);
    return result;
}

int32_t
Private_Write(NPP instance, NPStream* stream, int32_t offset, int32_t len,
        void* buffer)
{
    int32_t result;
    PLUGINDEBUGSTR("Write");
    result = NPP_Write(instance, stream, offset, len, buffer);

    return result;
}

void
Private_StreamAsFile(NPP instance, NPStream* stream, const char* fname)
{
    PLUGINDEBUGSTR("StreamAsFile");
    NPP_StreamAsFile(instance, stream, fname);
}

NPError
Private_DestroyStream(NPP instance, NPStream* stream, NPError reason)
{
    NPError err;
    PLUGINDEBUGSTR("DestroyStream");
    err = NPP_DestroyStream(instance, stream, reason);

    return err;
}

void
Private_URLNotify(NPP instance, const char* url, NPReason reason, void* notifyData)
{
    PLUGINDEBUGSTR("URLNotify");
    NPP_URLNotify(instance, url, reason, notifyData);
}

void
Private_Print(NPP instance, NPPrint* platformPrint)
{
    PLUGINDEBUGSTR("Print");
    NPP_Print(instance, platformPrint);
}

int16_t
Private_HandleEvent(NPP instance, void* event)
{
    int16_t result;
    PLUGINDEBUGSTR("HandleEvent");
    result = NPP_HandleEvent(instance, event);
    return result;
}

#pragma mark -
#pragma mark Initialization & Run

/*
** netscape plugins functions when building Mach-O binary
*/

extern "C" {
    NPError NP_Initialize(NPNetscapeFuncs* nsTable);
    NPError NP_GetEntryPoints(NPPluginFuncs* pluginFuncs);
    NPError NP_Shutdown(void);
}

/*
** netscape plugins functions when using Mach-O binary
*/

NPError
NP_Initialize(NPNetscapeFuncs* nsTable)
{
    /* validate input parameters */

    if (NULL == nsTable) {
        fprintf(stderr, "NP_Initialize error: NPERR_INVALID_FUNCTABLE_ERROR: table is null\n");
        return NPERR_INVALID_FUNCTABLE_ERROR;
    }

    /*
     * Check the major version passed in Netscape's function table.
     * We won't load if the major version is newer than what we expect.
     * Also check that the function tables passed in are big enough for
     * all the functions we need (they could be bigger, if Netscape added
     * new APIs, but that's OK with us -- we'll just ignore them).
     *
     */

    if ((nsTable->version >> 8) > NP_VERSION_MAJOR) {
        fprintf(stderr, "NP_Initialize error: NPERR_INCOMPATIBLE_VERSION_ERROR\n");
        return NPERR_INCOMPATIBLE_VERSION_ERROR;
    }


    // We use all functions of the nsTable up to and including pluginthreadasynccall. We therefore check that
    // reaches at least till that function.
    if (nsTable->size < (offsetof(NPNetscapeFuncs, pluginthreadasynccall) + sizeof(NPN_PluginThreadAsyncCallProcPtr))) {
        fprintf(stderr, "NP_Initialize error: NPERR_INVALID_FUNCTABLE_ERROR: table too small\n");
        return NPERR_INVALID_FUNCTABLE_ERROR;
    }

    gNetscapeFuncs = nsTable;

    return NPP_Initialize();
}

NPError
NP_GetEntryPoints(NPPluginFuncs* pluginFuncs)
{
    int minor = getMinorVersion();

    if (pluginFuncs == NULL)
        return NPERR_INVALID_FUNCTABLE_ERROR;

    /*if (pluginFuncs->size < sizeof(NPPluginFuncs))
    return NPERR_INVALID_FUNCTABLE_ERROR;*/

    /*
     * Set up the plugin function table that Netscape will use to
     * call us.  Netscape needs to know about our version and size
     * and have a UniversalProcPointer for every function we
     * implement.
     */

    pluginFuncs->version    = (NP_VERSION_MAJOR << 8) + NP_VERSION_MINOR;
    pluginFuncs->size       = sizeof(NPPluginFuncs);
    pluginFuncs->newp       = (NPP_NewProcPtr)(Private_New);
    pluginFuncs->destroy    = (NPP_DestroyProcPtr)(Private_Destroy);
    pluginFuncs->setwindow  = (NPP_SetWindowProcPtr)(Private_SetWindow);
    pluginFuncs->newstream  = (NPP_NewStreamProcPtr)(Private_NewStream);
    pluginFuncs->destroystream = (NPP_DestroyStreamProcPtr)(Private_DestroyStream);
    pluginFuncs->asfile     = (NPP_StreamAsFileProcPtr)(Private_StreamAsFile);
    pluginFuncs->writeready = (NPP_WriteReadyProcPtr)(Private_WriteReady);
    pluginFuncs->write      = (NPP_WriteProcPtr)(Private_Write);
    pluginFuncs->print      = (NPP_PrintProcPtr)(Private_Print);
    pluginFuncs->event      = (NPP_HandleEventProcPtr)(Private_HandleEvent);
    pluginFuncs->getvalue   = (NPP_GetValueProcPtr)(Private_GetValue);
    pluginFuncs->setvalue   = (NPP_SetValueProcPtr)(Private_SetValue);

    if (minor >= NPVERS_HAS_NOTIFICATION)
        pluginFuncs->urlnotify = Private_URLNotify;

    pluginFuncs->javaClass = NULL;

    return NPERR_NO_ERROR;
}

NPError
NP_Shutdown(void)
{
    PLUGINDEBUGSTR("NP_Shutdown");
    NPP_Shutdown();
    return NPERR_NO_ERROR;
}
