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

static NPNetscapeFuncs  *gNetscapeFuncs;    /* Netscape Function table */
short               gResFile;           // Refnum of the plugin’s resource file
static inline int getMinorVersion() { return gNetscapeFuncs->version & 0xFF; }


#pragma mark -
#pragma mark Wrapper Functions

void
NPN_Version(int* plugin_major, int* plugin_minor,
         int* netscape_major, int* netscape_minor)
{
    *plugin_major = NP_VERSION_MAJOR;
    *plugin_minor = NP_VERSION_MINOR;

    /* Major version is in high byte */
    *netscape_major = gNetscapeFuncs->version >> 8;
    /* Minor version is in low byte */
    *netscape_minor = getMinorVersion();
}


void NPN_PluginThreadAsyncCall(NPP instance, void (*func)(void *), void *userData)
{
    CALL_NPN(CallNPN_PluginThreadAsyncCallProc, gNetscapeFuncs->pluginthreadasynccall, instance, func, userData);
}

NPError
NPN_GetValue(NPP instance, NPNVariable variable, void *r_value)
{
    return CALL_NPN(CallNPN_GetValueProc, gNetscapeFuncs->getvalue,
                    instance, variable, r_value);
}

NPError
NPN_SetValue(NPP instance, NPPVariable variable, void *value)
{
    return CALL_NPN(CallNPN_SetValueProc, gNetscapeFuncs->setvalue,
                    instance, variable, value);
}

NPError
NPN_GetURL(NPP instance, const char* url, const char* window)
{
    return CALL_NPN(CallNPN_GetURLProc, gNetscapeFuncs->geturl, instance, url, window);
}

NPError
NPN_GetURLNotify(NPP instance, const char* url, const char* window, void* notifyData)
{
    int minor = getMinorVersion();
    NPError err;

    if (minor >= NPVERS_HAS_NOTIFICATION)
        err = CALL_NPN(CallNPN_GetURLNotifyProc, gNetscapeFuncs->geturlnotify, instance, url, window, notifyData);
    else
        err = NPERR_INCOMPATIBLE_VERSION_ERROR;

    return err;
}

NPError
NPN_PostURL(NPP instance, const char* url, const char* window,
         uint32_t len, const char* buf, NPBool file)
{
    return CALL_NPN(CallNPN_PostURLProc, gNetscapeFuncs->posturl, instance,
                    url, window, len, buf, file);
}

NPError
NPN_PostURLNotify(NPP instance, const char* url, const char* window, uint32_t len,
                  const char* buf, NPBool file, void* notifyData)
{
    int minor = getMinorVersion();
    NPError err;

    if (minor >= NPVERS_HAS_NOTIFICATION) {
        err = CALL_NPN(CallNPN_PostURLNotifyProc, gNetscapeFuncs->posturlnotify, instance, url,
                                                        window, len, buf, file, notifyData);
    }
    else
        err = NPERR_INCOMPATIBLE_VERSION_ERROR;

    return err;
}

NPError
NPN_RequestRead(NPStream* stream, NPByteRange* rangeList)
{
    return CALL_NPN(CallNPN_RequestReadProc, gNetscapeFuncs->requestread,
                    stream, rangeList);
}

NPError
NPN_NewStream(NPP instance, NPMIMEType type, const char *window,
          NPStream** stream)
{
    int minor = getMinorVersion();
    NPError err;

    if (minor >= NPVERS_HAS_STREAMOUTPUT)
        err = CALL_NPN(CallNPN_NewStreamProc, gNetscapeFuncs->newstream,
                instance, type, window, stream);
    else
        err = NPERR_INCOMPATIBLE_VERSION_ERROR;

    return err;
}

int32_t
NPN_Write(NPP instance, NPStream* stream, int32_t len, void* buffer)
{
    int minor = getMinorVersion();
    NPError err;

    if (minor >= NPVERS_HAS_STREAMOUTPUT)
        err = CALL_NPN(CallNPN_WriteProc, gNetscapeFuncs->write, instance, stream, len, buffer);
    else
        err = NPERR_INCOMPATIBLE_VERSION_ERROR;

    return err;
}

NPError
NPN_DestroyStream(NPP instance, NPStream* stream, NPError reason)
{
    int minor = getMinorVersion();
    NPError err;

    if (minor >= NPVERS_HAS_STREAMOUTPUT)
        err = CALL_NPN(CallNPN_DestroyStreamProc, gNetscapeFuncs->destroystream, instance, stream, reason);
    else
        err = NPERR_INCOMPATIBLE_VERSION_ERROR;

    return err;
}

void
NPN_Status(NPP instance, const char* message)
{
    CALL_NPN(CallNPN_StatusProc, gNetscapeFuncs->status, instance, message);
}

const char*
NPN_UserAgent(NPP instance)
{
    return CALL_NPN(CallNPN_UserAgentProc, gNetscapeFuncs->uagent, instance);
}

void*
NPN_MemAlloc(uint32_t size)
{
    return CALL_NPN(CallNPN_MemAllocProc, gNetscapeFuncs->memalloc, size);
}

void NPN_MemFree(void* ptr)
{
    CALL_NPN(CallNPN_MemFreeProc, gNetscapeFuncs->memfree, ptr);
}

uint32_t NPN_MemFlush(uint32_t size)
{
    return CALL_NPN(CallNPN_MemFlushProc, gNetscapeFuncs->memflush, size);
}

void NPN_ReloadPlugins(NPBool reloadPages)
{
    CALL_NPN(CallNPN_ReloadPluginsProc, gNetscapeFuncs->reloadplugins, reloadPages);
}

void
NPN_InvalidateRect(NPP instance, NPRect *invalidRect)
{
    CALL_NPN(CallNPN_InvalidateRectProc, gNetscapeFuncs->invalidaterect, instance,
        invalidRect);
}

void
NPN_InvalidateRegion(NPP instance, NPRegion invalidRegion)
{
    CALL_NPN(CallNPN_InvalidateRegionProc, gNetscapeFuncs->invalidateregion, instance,
        invalidRegion);
}

void
NPN_ForceRedraw(NPP instance)
{
    CALL_NPN(CallNPN_ForceRedrawProc, gNetscapeFuncs->forceredraw, instance);
}

NPIdentifier NPN_GetStringIdentifier(const NPUTF8 *name)
{
    int minor = getMinorVersion();
    if( minor >= 14 )
    {
        return CALL_NPN(CallNPN_GetStringIdentifierProc,
                        gNetscapeFuncs->getstringidentifier, name);
    }
    return NULL;
}

void NPN_GetStringIdentifiers(const NPUTF8 **names, int32_t nameCount,
                              NPIdentifier *identifiers)
{
    int minor = getMinorVersion();
    if( minor >= 14 )
        CALL_NPN(CallNPN_GetStringIdentifiersProc, gNetscapeFuncs->getstringidentifiers,
                                         names, nameCount, identifiers);
}

NPIdentifier NPN_GetIntIdentifier(int32_t intid)
{
    int minor = getMinorVersion();
    if( minor >= 14 )
        return CALL_NPN(CallNPN_GetIntIdentifierProc, gNetscapeFuncs->getintidentifier, intid);
    return NULL;
}

bool NPN_IdentifierIsString(NPIdentifier identifier)
{
    int minor = getMinorVersion();
    if( minor >= 14 )
    {
        return CALL_NPN(CallNPN_IdentifierIsStringProc,
                        gNetscapeFuncs->identifierisstring,
                        identifier);
    }
    return false;
}

NPUTF8 *NPN_UTF8FromIdentifier(NPIdentifier identifier)
{
    int minor = getMinorVersion();
    if( minor >= 14 )
        return CALL_NPN(CallNPN_UTF8FromIdentifierProc,
                            gNetscapeFuncs->utf8fromidentifier,
                            identifier);
    return NULL;
}

int32_t NPN_IntFromIdentifier(NPIdentifier identifier)
{
    int minor = getMinorVersion();
    if( minor >= 14 )
        return CALL_NPN(CallNPN_IntFromIdentifierProc,
                        gNetscapeFuncs->intfromidentifier,
                        identifier);
    return 0;
}

NPObject *NPN_CreateObject(NPP instance, NPClass *aClass)
{
    int minor = getMinorVersion();
    if( minor >= 14 )
        return CALL_NPN(CallNPN_CreateObjectProc, gNetscapeFuncs->createobject, instance, aClass);
    return NULL;
}

NPObject *NPN_RetainObject(NPObject *npobj)
{
    int minor = getMinorVersion();
    if( minor >= 14 )
        return CALL_NPN(CallNPN_RetainObjectProc, gNetscapeFuncs->retainobject, npobj);
    return NULL;
}

void NPN_ReleaseObject(NPObject *npobj)
{
    int minor = getMinorVersion();
    if( minor >= 14 )
        CALL_NPN(CallNPN_ReleaseObjectProc, gNetscapeFuncs->releaseobject, npobj);
}

bool NPN_Invoke(NPP instance, NPObject *npobj, NPIdentifier methodName,
                const NPVariant *args, uint32_t argCount, NPVariant *result)
{
    int minor = getMinorVersion();
    if( minor >= 14 )
        return CALL_NPN(CallNPN_InvokeProc, gNetscapeFuncs->invoke, instance, npobj, methodName,
                        args, argCount, result);
    return false;
}

bool NPN_InvokeDefault(NPP instance, NPObject *npobj, const NPVariant *args,
                       uint32_t argCount, NPVariant *result)
{
    int minor = getMinorVersion();
    if( minor >= 14 )
        return CALL_NPN(CallNPN_InvokeDefaultProc, gNetscapeFuncs->invokeDefault, instance, npobj,
                        args, argCount, result);
    return false;
}

bool NPN_Evaluate(NPP instance, NPObject *npobj, NPString *script, NPVariant *result)
{
    int minor = getMinorVersion();
    if( minor >= 14 )
        return CALL_NPN(CallNPN_EvaluateProc, gNetscapeFuncs->evaluate, instance, npobj,
                        script, result);
    return false;
}

bool NPN_GetProperty(NPP instance, NPObject *npobj, NPIdentifier propertyName,
                     NPVariant *result)
{
    int minor = getMinorVersion();
    if( minor >= 14 )
        return CALL_NPN(CallNPN_GetPropertyProc, gNetscapeFuncs->getproperty, instance, npobj,
                        propertyName, result);
    return false;
}

bool NPN_SetProperty(NPP instance, NPObject *npobj, NPIdentifier propertyName,
                     const NPVariant *value)
{
    int minor = getMinorVersion();
    if( minor >= 14 )
        return CALL_NPN(CallNPN_SetPropertyProc, gNetscapeFuncs->setproperty, instance, npobj,
                        propertyName, value);
    return false;
}

bool NPN_RemoveProperty(NPP instance, NPObject *npobj, NPIdentifier propertyName)
{
    int minor = getMinorVersion();
    if( minor >= 14 )
        return CALL_NPN(CallNPN_RemovePropertyProc, gNetscapeFuncs->removeproperty, instance, npobj,
                        propertyName);
    return false;
}

bool NPN_HasProperty(NPP instance, NPObject *npobj, NPIdentifier propertyName)
{
    int minor = getMinorVersion();
    if( minor >= 14 )
        return CALL_NPN(CallNPN_HasPropertyProc, gNetscapeFuncs->hasproperty, instance, npobj,
                        propertyName);
    return false;
}

bool NPN_HasMethod(NPP instance, NPObject *npobj, NPIdentifier methodName)
{
    int minor = getMinorVersion();
    if( minor >= 14 )
        return CALL_NPN(CallNPN_HasMethodProc, gNetscapeFuncs->hasmethod, instance,
                        npobj, methodName);
    return false;
}

void NPN_ReleaseVariantValue(NPVariant *variant)
{
    int minor = getMinorVersion();
    if( minor >= 14 )
        CALL_NPN(CallNPN_ReleaseVariantValueProc, gNetscapeFuncs->releasevariantvalue, variant);
}

void NPN_SetException(NPObject *npobj, const NPUTF8 *message)
{
    int minor = getMinorVersion();
    if( minor >= 14 )
        CALL_NPN(CallNPN_SetExceptionProc, gNetscapeFuncs->setexception, npobj, message);
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
