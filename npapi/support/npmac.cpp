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

#include "config.h"

#include <string.h>
#include <stddef.h>

#include "npapi.h"
#include "npfunctions.h"
#define CALL_NPN(unused, FN, ...) ((*FN)(__VA_ARGS__))

#include "../common.h"
#include "../vlcshell.h"


//
// Define PLUGIN_TRACE to 1 to have the wrapper functions emit
// DebugStr messages whenever they are called.
//
#define PLUGIN_TRACE 0

#if PLUGIN_TRACE
#define PLUGINDEBUGSTR(msg)     ::DebugStr(msg)
#else
#define PLUGINDEBUGSTR(msg) {}
#endif

#define PLUGIN_TO_HOST_GLUE(name, fp) (fp)
#define HOST_TO_PLUGIN_GLUE(name, fp) (fp)



#pragma mark -
#pragma mark Globals

short               gResFile;           // Refnum of the plugin’s resource file
NPNetscapeFuncs     gNetscapeFuncs;      // Function table for procs in Netscape called by plugin


#pragma mark -
#pragma mark Wrapper Functions

void NPN_Version(int* plugin_major, int* plugin_minor, int* netscape_major, int* netscape_minor)
{
    *plugin_major = NP_VERSION_MAJOR;
    *plugin_minor = NP_VERSION_MINOR;
    *netscape_major = gNetscapeFuncs.version >> 8;      // Major version is in high byte
    *netscape_minor = gNetscapeFuncs.version & 0xFF;    // Minor version is in low byte
}

NPError NPN_GetURLNotify(NPP instance, const char* url, const char* window, void* notifyData)
{
    int navMinorVers = gNetscapeFuncs.version & 0xFF;
    NPError err;

    if (navMinorVers >= NPVERS_HAS_NOTIFICATION)
        err = CALL_NPN(CallNPN_GetURLNotifyProc, gNetscapeFuncs.geturlnotify, instance, url, window, notifyData);
    else
        err = NPERR_INCOMPATIBLE_VERSION_ERROR;

    return err;
}

NPError NPN_GetURL(NPP instance, const char* url, const char* window)
{
    return CALL_NPN(CallNPN_GetURLProc, gNetscapeFuncs.geturl, instance, url, window);
}

NPError NPN_PostURLNotify(NPP instance, const char* url, const char* window, uint32_t len, const char* buf, NPBool file, void* notifyData)
{
    int navMinorVers = gNetscapeFuncs.version & 0xFF;
    NPError err;

    if (navMinorVers >= NPVERS_HAS_NOTIFICATION) {
        err = CALL_NPN(CallNPN_PostURLNotifyProc, gNetscapeFuncs.posturlnotify, instance, url,
                                                        window, len, buf, file, notifyData);
    }
    else
        err = NPERR_INCOMPATIBLE_VERSION_ERROR;

    return err;
}

NPError NPN_PostURL(NPP instance, const char* url, const char* window, uint32_t len, const char* buf, NPBool file)
{
    return CALL_NPN(CallNPN_PostURLProc, gNetscapeFuncs.posturl, instance, url, window, len, buf, file);
}

NPError NPN_RequestRead(NPStream* stream, NPByteRange* rangeList)
{
    return CALL_NPN(CallNPN_RequestReadProc, gNetscapeFuncs.requestread, stream, rangeList);
}

NPError NPN_NewStream(NPP instance, NPMIMEType type, const char* window, NPStream** stream)
{
    int navMinorVers = gNetscapeFuncs.version & 0xFF;
    NPError err;

    if (navMinorVers >= NPVERS_HAS_STREAMOUTPUT)
        err = CALL_NPN(CallNPN_NewStreamProc, gNetscapeFuncs.newstream, instance, type, window, stream);
    else
        err = NPERR_INCOMPATIBLE_VERSION_ERROR;

    return err;
}

int32_t NPN_Write(NPP instance, NPStream* stream, int32_t len, void* buffer)
{
    int navMinorVers = gNetscapeFuncs.version & 0xFF;
    NPError err;

    if (navMinorVers >= NPVERS_HAS_STREAMOUTPUT)
        err = CALL_NPN(CallNPN_WriteProc, gNetscapeFuncs.write, instance, stream, len, buffer);
    else
        err = NPERR_INCOMPATIBLE_VERSION_ERROR;

    return err;
}

NPError NPN_DestroyStream(NPP instance, NPStream* stream, NPError reason)
{
    int navMinorVers = gNetscapeFuncs.version & 0xFF;
    NPError err;

    if (navMinorVers >= NPVERS_HAS_STREAMOUTPUT)
        err = CALL_NPN(CallNPN_DestroyStreamProc, gNetscapeFuncs.destroystream, instance, stream, reason);
    else
        err = NPERR_INCOMPATIBLE_VERSION_ERROR;

    return err;
}

void NPN_Status(NPP instance, const char* message)
{
    CALL_NPN(CallNPN_StatusProc, gNetscapeFuncs.status, instance, message);
}

const char* NPN_UserAgent(NPP instance)
{
    return CALL_NPN(CallNPN_UserAgentProc, gNetscapeFuncs.uagent, instance);
}

void* NPN_MemAlloc(uint32_t size)
{
    return CALL_NPN(CallNPN_MemAllocProc, gNetscapeFuncs.memalloc, size);
}

void NPN_MemFree(void* ptr)
{
    CALL_NPN(CallNPN_MemFreeProc, gNetscapeFuncs.memfree, ptr);
}

uint32_t NPN_MemFlush(uint32_t size)
{
    return CALL_NPN(CallNPN_MemFlushProc, gNetscapeFuncs.memflush, size);
}

void NPN_ReloadPlugins(NPBool reloadPages)
{
    CALL_NPN(CallNPN_ReloadPluginsProc, gNetscapeFuncs.reloadplugins, reloadPages);
}

void NPN_PluginThreadAsyncCall(NPP instance, void (*func)(void *), void *userData)
{
    CALL_NPN(CallNPN_PluginThreadAsyncCallProc, gNetscapeFuncs.pluginthreadasynccall, instance, func, userData);
}

NPError NPN_GetValue(NPP instance, NPNVariable variable, void *value)
{
    return CALL_NPN(CallNPN_GetValueProc, gNetscapeFuncs.getvalue, instance, variable, value);
}

NPError NPN_SetValue(NPP instance, NPPVariable variable, void *value)
{
    return CALL_NPN(CallNPN_SetValueProc, gNetscapeFuncs.setvalue, instance, variable, value);
}

void NPN_InvalidateRect(NPP instance, NPRect *rect)
{
    CALL_NPN(CallNPN_InvalidateRectProc, gNetscapeFuncs.invalidaterect, instance, rect);
}

void NPN_InvalidateRegion(NPP instance, NPRegion region)
{
    CALL_NPN(CallNPN_InvalidateRegionProc, gNetscapeFuncs.invalidateregion, instance, region);
}

void NPN_ForceRedraw(NPP instance)
{
    CALL_NPN(CallNPN_ForceRedrawProc, gNetscapeFuncs.forceredraw, instance);
}

NPIdentifier NPN_GetStringIdentifier(const NPUTF8 *name)
{
    int navMinorVers = gNetscapeFuncs.version & 0xFF;
    if (navMinorVers >= 14)
        return CALL_NPN(CallNPN_GetStringIdentifierProc, gNetscapeFuncs.getstringidentifier, name);

    return NULL;
}

void NPN_GetStringIdentifiers(const NPUTF8 **names, int32_t nameCount, NPIdentifier *identifiers)
{
    int navMinorVers = gNetscapeFuncs.version & 0xFF;
    if (navMinorVers >= 14)
        CALL_NPN(CallNPN_GetStringIdentifiersProc, gNetscapeFuncs.getstringidentifiers, names, nameCount, identifiers);
}

NPIdentifier NPN_GetIntIdentifier(int32_t intid)
{
    int navMinorVers = gNetscapeFuncs.version & 0xFF;
    if (navMinorVers >= 14)
        return CALL_NPN(CallNPN_GetIntIdentifierProc, gNetscapeFuncs.getintidentifier, intid);

    return NULL;
}

bool NPN_IdentifierIsString(NPIdentifier identifier)
{
    int navMinorVers = gNetscapeFuncs.version & 0xFF;
    if (navMinorVers >= 14)
        return CALL_NPN(CallNPN_IdentifierIsStringProc, gNetscapeFuncs.identifierisstring, identifier);

    return false;
}

NPUTF8 *NPN_UTF8FromIdentifier(NPIdentifier identifier)
{
    int navMinorVers = gNetscapeFuncs.version & 0xFF;
    if (navMinorVers >= 14)
        return CALL_NPN(CallNPN_UTF8FromIdentifierProc, gNetscapeFuncs.utf8fromidentifier, identifier);

    return NULL;
}

int32_t NPN_IntFromIdentifier(NPIdentifier identifier)
{
    int navMinorVers = gNetscapeFuncs.version & 0xFF;
    if (navMinorVers >= 14)
        return CALL_NPN(CallNPN_IntFromIdentifierProc, gNetscapeFuncs.intfromidentifier, identifier);

    return 0;
}

NPObject *NPN_CreateObject(NPP instance, NPClass *aClass)
{
    int navMinorVers = gNetscapeFuncs.version & 0xFF;
    if (navMinorVers >= 14)
        return CALL_NPN(CallNPN_CreateObjectProc, gNetscapeFuncs.createobject, instance, aClass);

    return NULL;
}

NPObject *NPN_RetainObject(NPObject *npobj)
{
    int navMinorVers = gNetscapeFuncs.version & 0xFF;
    if (navMinorVers >= 14)
        return CALL_NPN(CallNPN_RetainObjectProc, gNetscapeFuncs.retainobject, npobj);

    return NULL;
}

void NPN_ReleaseObject(NPObject *npobj)
{
    int navMinorVers = gNetscapeFuncs.version & 0xFF;
    if (navMinorVers >= 14)
        CALL_NPN(CallNPN_ReleaseObjectProc, gNetscapeFuncs.releaseobject, npobj);
}

bool NPN_Invoke(NPP instance, NPObject *npobj, NPIdentifier methodName, const NPVariant *args, uint32_t argCount, NPVariant *result)
{
    int navMinorVers = gNetscapeFuncs.version & 0xFF;
    if (navMinorVers >= 14)
        return CALL_NPN(CallNPN_InvokeProc, gNetscapeFuncs.invoke, instance, npobj, methodName, args, argCount, result);

    return false;
}

bool NPN_InvokeDefault(NPP instance, NPObject *npobj, const NPVariant *args, uint32_t argCount, NPVariant *result)
{
    int navMinorVers = gNetscapeFuncs.version & 0xFF;
    if (navMinorVers >= 14)
        return CALL_NPN(CallNPN_InvokeDefaultProc, gNetscapeFuncs.invokeDefault, instance, npobj, args, argCount, result);

    return false;
}

bool NPN_Evaluate(NPP instance, NPObject *npobj, NPString *script, NPVariant *result)
{
    int navMinorVers = gNetscapeFuncs.version & 0xFF;
    if (navMinorVers >= 14)
        return CALL_NPN(CallNPN_EvaluateProc, gNetscapeFuncs.evaluate, instance, npobj, script, result);

    return false;
}

bool NPN_GetProperty(NPP instance, NPObject *npobj, NPIdentifier propertyName, NPVariant *result)
{
    int navMinorVers = gNetscapeFuncs.version & 0xFF;
    if (navMinorVers >= 14)
        return CALL_NPN(CallNPN_GetPropertyProc, gNetscapeFuncs.getproperty, instance, npobj, propertyName, result);

    return false;
}

bool NPN_SetProperty(NPP instance, NPObject *npobj, NPIdentifier propertyName, const NPVariant *value)
{
    int navMinorVers = gNetscapeFuncs.version & 0xFF;
    if (navMinorVers >= 14)
        return CALL_NPN(CallNPN_SetPropertyProc, gNetscapeFuncs.setproperty, instance, npobj, propertyName, value);

    return false;
}

bool NPN_RemoveProperty(NPP instance, NPObject *npobj, NPIdentifier propertyName)
{
    int navMinorVers = gNetscapeFuncs.version & 0xFF;
    if (navMinorVers >= 14)
        return CALL_NPN(CallNPN_RemovePropertyProc, gNetscapeFuncs.removeproperty, instance, npobj, propertyName);

    return false;
}

bool NPN_HasProperty(NPP instance, NPObject *npobj, NPIdentifier propertyName)
{
    int navMinorVers = gNetscapeFuncs.version & 0xFF;
    if (navMinorVers >= 14)
        return CALL_NPN(CallNPN_HasPropertyProc, gNetscapeFuncs.hasproperty, instance, npobj, propertyName);

    return false;
}

bool NPN_HasMethod(NPP instance, NPObject *npobj, NPIdentifier methodName)
{
    int navMinorVers = gNetscapeFuncs.version & 0xFF;
    if (navMinorVers >= 14)
        return CALL_NPN(CallNPN_HasMethodProc, gNetscapeFuncs.hasmethod, instance, npobj, methodName);

    return false;
}

void NPN_ReleaseVariantValue(NPVariant *variant)
{
    int navMinorVers = gNetscapeFuncs.version & 0xFF;
    if (navMinorVers >= 14)
        CALL_NPN(CallNPN_ReleaseVariantValueProc, gNetscapeFuncs.releasevariantvalue, variant);
}

void NPN_SetException(NPObject *npobj, const NPUTF8 *message)
{
    int navMinorVers = gNetscapeFuncs.version & 0xFF;
    if (navMinorVers >= 14)
        CALL_NPN(CallNPN_SetExceptionProc, gNetscapeFuncs.setexception, npobj, message);
}

#pragma mark -
#pragma mark Private Functions

NPError     Private_Initialize(void);
void        Private_Shutdown(void);
NPError     Private_New(NPMIMEType pluginType, NPP instance, uint16_t mode, int16_t argc, char* argn[], char* argv[], NPSavedData* saved);
NPError     Private_Destroy(NPP instance, NPSavedData** save);
NPError     Private_SetWindow(NPP instance, NPWindow* window);
NPError     Private_GetValue( NPP instance, NPPVariable variable, void *value);
NPError     Private_SetValue( NPP instance, NPPVariable variable, void *value);
NPError     Private_NewStream(NPP instance, NPMIMEType type, NPStream* stream, NPBool seekable, uint16_t* stype);
NPError     Private_DestroyStream(NPP instance, NPStream* stream, NPError reason);
int32_t     Private_WriteReady(NPP instance, NPStream* stream);
int32_t     Private_Write(NPP instance, NPStream* stream, int32_t offset, int32_t len, void* buffer);
void        Private_StreamAsFile(NPP instance, NPStream* stream, const char* fname);
void        Private_Print(NPP instance, NPPrint* platformPrint);
int16_t     Private_HandleEvent(NPP instance, void* event);
void        Private_URLNotify(NPP instance, const char* url, NPReason reason, void* notifyData);


NPError Private_Initialize(void)
{
    NPError err;
    PLUGINDEBUGSTR("\pInitialize;g;");
    err = NPP_Initialize();
    return err;
}

void Private_Shutdown(void)
{
    PLUGINDEBUGSTR("\pShutdown;g;");
    NPP_Shutdown();
}

static bool boolValue(const char *value) {
    return ( !strcmp(value, "1") ||
            !strcasecmp(value, "true") ||
            !strcasecmp(value, "yes") );
}

NPError    Private_New(NPMIMEType pluginType, NPP instance, uint16_t mode, int16_t argc, char* argn[], char* argv[], NPSavedData* saved)
{
    PLUGINDEBUGSTR("\pNew;g;");

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
        printf("running in windowless\n");
        NPBool supportsCoreGraphics = FALSE;
        err = NPN_GetValue(instance, NPNVsupportsCoreGraphicsBool, &supportsCoreGraphics);
        if (err != NPERR_NO_ERROR || !supportsCoreGraphics) {
            PLUGINDEBUGSTR("\pNew: browser doesn't support CoreGraphics drawing model;g;");
            return NPERR_INCOMPATIBLE_VERSION_ERROR;
        }

        err = NPN_SetValue(instance, NPPVpluginDrawingModel, (void*)NPDrawingModelCoreGraphics);
        if (err != NPERR_NO_ERROR) {
            PLUGINDEBUGSTR("\pNew: couldn't activate CoreGraphics drawing model;g;");
            return NPERR_INCOMPATIBLE_VERSION_ERROR;
        }
    } else {
        printf("running windowed\n");
        NPBool supportsCoreAnimation = FALSE;
        err = NPN_GetValue(instance, NPNVsupportsCoreAnimationBool, &supportsCoreAnimation);
        if (err != NPERR_NO_ERROR || !supportsCoreAnimation) {
            PLUGINDEBUGSTR("\pNew: browser doesn't support CoreAnimation drawing model;g;");
            return NPERR_INCOMPATIBLE_VERSION_ERROR;
        }

        NPBool supportsInvalidatingCoreAnimation = FALSE;
        err = NPN_GetValue(instance, NPNVsupportsInvalidatingCoreAnimationBool, &supportsInvalidatingCoreAnimation);
        if (err != NPERR_NO_ERROR || !supportsInvalidatingCoreAnimation)
            PLUGINDEBUGSTR("\pNew: browser doesn't support the Invalidating CoreAnimation drawing model;g;");

        if (supportsInvalidatingCoreAnimation) {
            err = NPN_SetValue(instance, NPPVpluginDrawingModel, (void*)NPDrawingModelInvalidatingCoreAnimation);
            if (err != NPERR_NO_ERROR) {
                PLUGINDEBUGSTR("\pNew: couldn't activate Invalidating CoreAnimation drawing model;g;");
                return NPERR_INCOMPATIBLE_VERSION_ERROR;
            }
        } else {
            PLUGINDEBUGSTR("\pNew: falling back to non-invalidating CoreAnimation drawing, since invalidation is not supported;g;");
            err = NPN_SetValue(instance, NPPVpluginDrawingModel, (void*)NPDrawingModelCoreAnimation);
            if (err != NPERR_NO_ERROR) {
                PLUGINDEBUGSTR("\pNew: couldn't activate CoreAnimation drawing model;g;");
                return NPERR_INCOMPATIBLE_VERSION_ERROR;
            }
        }
    }

    NPBool supportsCocoaEvents = FALSE;
    err = NPN_GetValue(instance, NPNVsupportsCocoaBool, &supportsCocoaEvents);
    if (err != NPERR_NO_ERROR || !supportsCocoaEvents) {
		PLUGINDEBUGSTR("\pNew: browser doesn't support Cocoa event model;g;");
		return NPERR_INCOMPATIBLE_VERSION_ERROR;
	}

    err = NPN_SetValue(instance, NPPVpluginEventModel, (void*)NPEventModelCocoa);
    if (err != NPERR_NO_ERROR) {
    	PLUGINDEBUGSTR("\pNew: couldn't activate Cocoa event model;g;");
    	return NPERR_INCOMPATIBLE_VERSION_ERROR;
    }

    NPError ret = NPP_New(pluginType, instance, mode, argc, argn, argv, saved);

    return ret;
}

NPError Private_Destroy(NPP instance, NPSavedData** save)
{
    NPError err;
    PLUGINDEBUGSTR("\pDestroy;g;");
    err = NPP_Destroy(instance, save);

    return err;
}

NPError Private_SetWindow(NPP instance, NPWindow* window)
{
    NPError err;
    PLUGINDEBUGSTR("\pSetWindow;g;");
    err = NPP_SetWindow(instance, window);

    return err;
}

NPError Private_GetValue( NPP instance, NPPVariable variable, void *value)
{
    NPError err;
    PLUGINDEBUGSTR("\pGetValue;g;");
    err = NPP_GetValue(instance, variable, value);

    return err;
}

NPError Private_SetValue( NPP instance, NPNVariable variable, void *value)
{
    NPError err;
    PLUGINDEBUGSTR("\pSetValue;g;");
    err = NPP_SetValue(instance, variable, value);

    return err;
}

NPError Private_NewStream(NPP instance, NPMIMEType type, NPStream* stream, NPBool seekable, uint16_t* stype)
{
    NPError err;
    PLUGINDEBUGSTR("\pNewStream;g;");
    err = NPP_NewStream(instance, type, stream, seekable, stype);

    return err;
}

int32_t Private_WriteReady(NPP instance, NPStream* stream)
{
    int32_t result;
    PLUGINDEBUGSTR("\pWriteReady;g;");
    result = NPP_WriteReady(instance, stream);

    return result;
}

int32_t Private_Write(NPP instance, NPStream* stream, int32_t offset, int32_t len, void* buffer)
{
    int32_t result;
    PLUGINDEBUGSTR("\pWrite;g;");
    result = NPP_Write(instance, stream, offset, len, buffer);

    return result;
}

void Private_StreamAsFile(NPP instance, NPStream* stream, const char* fname)
{
    PLUGINDEBUGSTR("\pStreamAsFile;g;");
    NPP_StreamAsFile(instance, stream, fname);
}

NPError Private_DestroyStream(NPP instance, NPStream* stream, NPError reason)
{
    NPError err;
    PLUGINDEBUGSTR("\pDestroyStream;g;");
    err = NPP_DestroyStream(instance, stream, reason);

    return err;
}

int16_t Private_HandleEvent(NPP instance, void* event)
{
    int16_t result;
    PLUGINDEBUGSTR("\pHandleEvent;g;");
    result = NPP_HandleEvent(instance, event);

    return result;
}

void Private_Print(NPP instance, NPPrint* platformPrint)
{
    PLUGINDEBUGSTR("\pPrint;g;");
    NPP_Print(instance, platformPrint);
}

void Private_URLNotify(NPP instance, const char* url, NPReason reason, void* notifyData)
{
    PLUGINDEBUGSTR("\pURLNotify;g;");
    NPP_URLNotify(instance, url, reason, notifyData);
}

#pragma mark -
#pragma mark Initialization & Run

// gcc requires that main have an 'int' return type
typedef int main_return_t;
typedef void (* NP_LOADDS NPP_ShutdownProcPtr)(void);
typedef NPP_ShutdownProcPtr unloadupp_t;

main_return_t main(NPNetscapeFuncs* nsTable, NPPluginFuncs* pluginFuncs, unloadupp_t* unloadUpp);

DEFINE_API_C(main_return_t) main(NPNetscapeFuncs* nsTable, NPPluginFuncs* pluginFuncs, unloadupp_t* unloadUpp)
{
    PLUGINDEBUGSTR("\pmain");

    NPError err = NPERR_NO_ERROR;

    //
    // Ensure that everything Netscape passed us is valid!
    //
    if ((nsTable == NULL) || (pluginFuncs == NULL) || (unloadUpp == NULL))
        err = NPERR_INVALID_FUNCTABLE_ERROR;

    //
    // Check the “major” version passed in Netscape’s function table.
    // We won’t load if the major version is newer than what we expect.
    // Also check that the function tables passed in are big enough for
    // all the functions we need (they could be bigger, if Netscape added
    // new APIs, but that’s OK with us -- we’ll just ignore them).
    //
    if (err == NPERR_NO_ERROR) {
        if ((nsTable->version >> 8) > NP_VERSION_MAJOR)     // Major version is in high byte
            err = NPERR_INCOMPATIBLE_VERSION_ERROR;
    }

    if (err == NPERR_NO_ERROR) {
        //
        // Copy all the fields of Netscape’s function table into our
        // copy so we can call back into Netscape later.  Note that
        // we need to copy the fields one by one, rather than assigning
        // the whole structure, because the Netscape function table
        // could actually be bigger than what we expect.
        //

        int navMinorVers = nsTable->version & 0xFF;

        gNetscapeFuncs.version          = nsTable->version;
        gNetscapeFuncs.size             = nsTable->size;
        gNetscapeFuncs.posturl          = HOST_TO_PLUGIN_GLUE(posturl, nsTable->posturl);
        gNetscapeFuncs.geturl           = HOST_TO_PLUGIN_GLUE(geturl, nsTable->geturl);
        gNetscapeFuncs.requestread      = HOST_TO_PLUGIN_GLUE(requestread, nsTable->requestread);
        gNetscapeFuncs.newstream        = HOST_TO_PLUGIN_GLUE(newstream, nsTable->newstream);
        gNetscapeFuncs.write            = HOST_TO_PLUGIN_GLUE(write, nsTable->write);
        gNetscapeFuncs.destroystream    = HOST_TO_PLUGIN_GLUE(destroystream, nsTable->destroystream);
        gNetscapeFuncs.status           = HOST_TO_PLUGIN_GLUE(status, nsTable->status);
        gNetscapeFuncs.uagent           = HOST_TO_PLUGIN_GLUE(uagent, nsTable->uagent);
        gNetscapeFuncs.memalloc         = HOST_TO_PLUGIN_GLUE(memalloc, nsTable->memalloc);
        gNetscapeFuncs.memfree          = HOST_TO_PLUGIN_GLUE(memfree, nsTable->memfree);
        gNetscapeFuncs.memflush         = HOST_TO_PLUGIN_GLUE(memflush, nsTable->memflush);
        gNetscapeFuncs.reloadplugins    = HOST_TO_PLUGIN_GLUE(reloadplugins, nsTable->reloadplugins);
        if (navMinorVers >= NPVERS_HAS_LIVECONNECT) {
            gNetscapeFuncs.getJavaEnv   = HOST_TO_PLUGIN_GLUE(getJavaEnv, nsTable->getJavaEnv);
            gNetscapeFuncs.getJavaPeer  = HOST_TO_PLUGIN_GLUE(getJavaPeer, nsTable->getJavaPeer);
        }
        if (navMinorVers >= NPVERS_HAS_NOTIFICATION) {
            gNetscapeFuncs.geturlnotify = HOST_TO_PLUGIN_GLUE(geturlnotify, nsTable->geturlnotify);
            gNetscapeFuncs.posturlnotify    = HOST_TO_PLUGIN_GLUE(posturlnotify, nsTable->posturlnotify);
        }
        gNetscapeFuncs.getvalue         = HOST_TO_PLUGIN_GLUE(getvalue, nsTable->getvalue);
        gNetscapeFuncs.setvalue         = HOST_TO_PLUGIN_GLUE(setvalue, nsTable->setvalue);
        gNetscapeFuncs.invalidaterect   = HOST_TO_PLUGIN_GLUE(invalidaterect, nsTable->invalidaterect);
        gNetscapeFuncs.invalidateregion = HOST_TO_PLUGIN_GLUE(invalidateregion, nsTable->invalidateregion);
        gNetscapeFuncs.forceredraw      = HOST_TO_PLUGIN_GLUE(forceredraw, nsTable->forceredraw);
        if (navMinorVers >= 14) {
            // NPRuntime support
            gNetscapeFuncs.getstringidentifier   = HOST_TO_PLUGIN_GLUE(getstringidentifier, nsTable->getstringidentifier);
            gNetscapeFuncs.getstringidentifiers  = HOST_TO_PLUGIN_GLUE(getstringidentifiers, nsTable->getstringidentifiers);
            gNetscapeFuncs.getintidentifier      = HOST_TO_PLUGIN_GLUE(getintidentifier, nsTable->getintidentifier);
            gNetscapeFuncs.identifierisstring    = HOST_TO_PLUGIN_GLUE(identifierisstring, nsTable->identifierisstring);
            gNetscapeFuncs.utf8fromidentifier    = HOST_TO_PLUGIN_GLUE(utf8fromidentifier, nsTable->utf8fromidentifier);
            gNetscapeFuncs.intfromidentifier     = HOST_TO_PLUGIN_GLUE(intfromidentifier, nsTable->intfromidentifier);
            gNetscapeFuncs.createobject          = HOST_TO_PLUGIN_GLUE(createobject, nsTable->createobject);
            gNetscapeFuncs.retainobject          = HOST_TO_PLUGIN_GLUE(retainobject, nsTable->retainobject);
            gNetscapeFuncs.releaseobject         = HOST_TO_PLUGIN_GLUE(releaseobject, nsTable->releaseobject);
            gNetscapeFuncs.invoke                = HOST_TO_PLUGIN_GLUE(invoke, nsTable->invoke);
            gNetscapeFuncs.invokeDefault         = HOST_TO_PLUGIN_GLUE(invokeDefault, nsTable->invokeDefault);
            gNetscapeFuncs.evaluate              = HOST_TO_PLUGIN_GLUE(evaluate, nsTable->evaluate);
            gNetscapeFuncs.getproperty           = HOST_TO_PLUGIN_GLUE(getproperty, nsTable->getproperty);
            gNetscapeFuncs.setproperty           = HOST_TO_PLUGIN_GLUE(setproperty, nsTable->setproperty);
            gNetscapeFuncs.removeproperty        = HOST_TO_PLUGIN_GLUE(removeproperty, nsTable->removeproperty);
            gNetscapeFuncs.hasproperty           = HOST_TO_PLUGIN_GLUE(hasproperty, nsTable->hasproperty);
            gNetscapeFuncs.hasmethod             = HOST_TO_PLUGIN_GLUE(hasmethod, nsTable->hasmethod);
            gNetscapeFuncs.releasevariantvalue   = HOST_TO_PLUGIN_GLUE(releasevariantvalue, nsTable->releasevariantvalue);
            gNetscapeFuncs.setexception          = HOST_TO_PLUGIN_GLUE(setexception, nsTable->setexception);
            gNetscapeFuncs.pluginthreadasynccall = HOST_TO_PLUGIN_GLUE(pluginthreadasynccall, nsTable->pluginthreadasynccall);
        }

        //
        // Set up the plugin function table that Netscape will use to
        // call us.  Netscape needs to know about our version and size
        // and have a UniversalProcPointer for every function we implement.
        //
        pluginFuncs->version        = (NP_VERSION_MAJOR << 8) + NP_VERSION_MINOR;
        pluginFuncs->size           = sizeof(NPPluginFuncs);
        pluginFuncs->newp           = (NPP_NewProcPtr)(PLUGIN_TO_HOST_GLUE(newp, Private_New));
        pluginFuncs->destroy        = (NPP_DestroyProcPtr)(PLUGIN_TO_HOST_GLUE(destroy, Private_Destroy));
        pluginFuncs->setwindow      = (NPP_SetWindowProcPtr)(PLUGIN_TO_HOST_GLUE(setwindow, Private_SetWindow));
        pluginFuncs->newstream      = (NPP_NewStreamProcPtr)(PLUGIN_TO_HOST_GLUE(newstream, Private_NewStream));
        pluginFuncs->destroystream  = (NPP_DestroyStreamProcPtr)(PLUGIN_TO_HOST_GLUE(destroystream, Private_DestroyStream));
        pluginFuncs->asfile         = (NPP_StreamAsFileProcPtr)(PLUGIN_TO_HOST_GLUE(asfile, Private_StreamAsFile));
        pluginFuncs->writeready     = (NPP_WriteReadyProcPtr)(PLUGIN_TO_HOST_GLUE(writeready, Private_WriteReady));
        pluginFuncs->write          = (NPP_WriteProcPtr)(PLUGIN_TO_HOST_GLUE(write, Private_Write));
        pluginFuncs->print          = (NPP_PrintProcPtr)(PLUGIN_TO_HOST_GLUE(print, Private_Print));
        pluginFuncs->event          = (NPP_HandleEventProcPtr)(PLUGIN_TO_HOST_GLUE(event, Private_HandleEvent));
        pluginFuncs->getvalue       = (NPP_GetValueProcPtr)(PLUGIN_TO_HOST_GLUE(getvalue, Private_GetValue));

        if (navMinorVers >= NPVERS_HAS_NOTIFICATION)
            pluginFuncs->urlnotify = (NPP_URLNotifyProcPtr)(PLUGIN_TO_HOST_GLUE(urlnotify, Private_URLNotify));

        pluginFuncs->javaClass = NULL;

        *unloadUpp = (NPP_ShutdownProcPtr)(PLUGIN_TO_HOST_GLUE(shutdown, Private_Shutdown));

        err = Private_Initialize();
    }

    return err;
}

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

NPError NP_Initialize(NPNetscapeFuncs* nsTable)
{
    PLUGINDEBUGSTR("\pNP_Initialize");

    /* validate input parameters */

    if (NULL == nsTable) {
    	PLUGINDEBUGSTR("\pNP_Initialize error: NPERR_INVALID_FUNCTABLE_ERROR: table is null");
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
    	PLUGINDEBUGSTR("\pNP_Initialize error: NPERR_INCOMPATIBLE_VERSION_ERROR");
        return NPERR_INCOMPATIBLE_VERSION_ERROR;
    }


    // We use all functions of the nsTable up to and including pluginthreadasynccall. We therefore check that
    // reaches at least till that function.
    if (nsTable->size < (offsetof(NPNetscapeFuncs, pluginthreadasynccall) + sizeof(NPN_PluginThreadAsyncCallProcPtr))) {
    	PLUGINDEBUGSTR("\pNP_Initialize error: NPERR_INVALID_FUNCTABLE_ERROR: table too small");
        return NPERR_INVALID_FUNCTABLE_ERROR;
    }

    int navMinorVers = nsTable->version & 0xFF;

    /*
     * Copy all the fields of Netscape function table into our
     * copy so we can call back into Netscape later.  Note that
     * we need to copy the fields one by one, rather than assigning
     * the whole structure, because the Netscape function table
     * could actually be bigger than what we expect.
     */
    gNetscapeFuncs.version       = nsTable->version;
    gNetscapeFuncs.size          = nsTable->size;
    gNetscapeFuncs.posturl       = nsTable->posturl;
    gNetscapeFuncs.geturl        = nsTable->geturl;
    gNetscapeFuncs.requestread   = nsTable->requestread;
    gNetscapeFuncs.newstream     = nsTable->newstream;
    gNetscapeFuncs.write         = nsTable->write;
    gNetscapeFuncs.destroystream = nsTable->destroystream;
    gNetscapeFuncs.status        = nsTable->status;
    gNetscapeFuncs.uagent        = nsTable->uagent;
    gNetscapeFuncs.memalloc      = nsTable->memalloc;
    gNetscapeFuncs.memfree       = nsTable->memfree;
    gNetscapeFuncs.memflush      = nsTable->memflush;
    gNetscapeFuncs.reloadplugins = nsTable->reloadplugins;
    if (navMinorVers >= NPVERS_HAS_LIVECONNECT) {
        gNetscapeFuncs.getJavaEnv   = nsTable->getJavaEnv;
        gNetscapeFuncs.getJavaPeer  = nsTable->getJavaPeer;
    }
    if (navMinorVers >= NPVERS_HAS_NOTIFICATION) {
        gNetscapeFuncs.geturlnotify     = nsTable->geturlnotify;
        gNetscapeFuncs.posturlnotify    = nsTable->posturlnotify;
    }

    gNetscapeFuncs.getvalue         = nsTable->getvalue;
    gNetscapeFuncs.setvalue         = nsTable->setvalue;
    gNetscapeFuncs.invalidaterect   = nsTable->invalidaterect;
    gNetscapeFuncs.invalidateregion = nsTable->invalidateregion;
    gNetscapeFuncs.forceredraw      = nsTable->forceredraw;
    if (navMinorVers >= 14) {
        // NPRuntime support
        gNetscapeFuncs.getstringidentifier   = nsTable->getstringidentifier;
        gNetscapeFuncs.getstringidentifiers  = nsTable->getstringidentifiers;
        gNetscapeFuncs.getintidentifier      = nsTable->getintidentifier;
        gNetscapeFuncs.identifierisstring    = nsTable->identifierisstring;
        gNetscapeFuncs.utf8fromidentifier    = nsTable->utf8fromidentifier;
        gNetscapeFuncs.intfromidentifier     = nsTable->intfromidentifier;
        gNetscapeFuncs.createobject          = nsTable->createobject;
        gNetscapeFuncs.retainobject          = nsTable->retainobject;
        gNetscapeFuncs.releaseobject         = nsTable->releaseobject;
        gNetscapeFuncs.invoke                = nsTable->invoke;
        gNetscapeFuncs.invokeDefault         = nsTable->invokeDefault;
        gNetscapeFuncs.evaluate              = nsTable->evaluate;
        gNetscapeFuncs.getproperty           = nsTable->getproperty;
        gNetscapeFuncs.setproperty           = nsTable->setproperty;
        gNetscapeFuncs.removeproperty        = nsTable->removeproperty;
        gNetscapeFuncs.hasproperty           = nsTable->hasproperty;
        gNetscapeFuncs.hasmethod             = nsTable->hasmethod;
        gNetscapeFuncs.releasevariantvalue   = nsTable->releasevariantvalue;
        gNetscapeFuncs.setexception          = nsTable->setexception;
        gNetscapeFuncs.pluginthreadasynccall = nsTable->pluginthreadasynccall;
    }
    return NPP_Initialize();
}

NPError NP_GetEntryPoints(NPPluginFuncs* pluginFuncs)
{
    int navMinorVers = gNetscapeFuncs.version & 0xFF;

    PLUGINDEBUGSTR("\pNP_GetEntryPoints");

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

    if (navMinorVers >= NPVERS_HAS_NOTIFICATION)
        pluginFuncs->urlnotify = Private_URLNotify;

    pluginFuncs->javaClass = NULL;

    return NPERR_NO_ERROR;
}

NPError NP_Shutdown(void)
{
    PLUGINDEBUGSTR("\pNP_Shutdown");
    NPP_Shutdown();
    return NPERR_NO_ERROR;
}
