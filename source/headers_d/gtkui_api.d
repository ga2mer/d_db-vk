/*
  gtkui_api.h -- API of the DeaDBeeF GTK UI plugin
  http://deadbeef.sourceforge.net

  Copyright (C) 2009-2013 Alexey Yakovenko

  This software is provided 'as-is', without any express or implied
  warranty.  In no event will the authors be held liable for any damages
  arising from the use of this software.

  Permission is granted to anyone to use this software for any purpose,
  including commercial applications, and to alter it and redistribute it
  freely, subject to the following restrictions:

  1. The origin of this software must not be misrepresented; you must not
     claim that you wrote the original software. If you use this software
     in a product, an acknowledgment in the product documentation would be
     appreciated but is not required.
  2. Altered source versions must be plainly marked as such, and must not be
     misrepresented as being the original software.
  3. This notice may not be removed or altered from any source distribution.

  Note: DeaDBeeF player itself uses different license
*/
module gtkui_api;
import core.stdc.stdint;
import gtk.c.types;
import db;

extern (C):

// gtkui.version_major=2 corresponds to deadbeef 0.6
// this is the version which has added design mode.
// it's guaranteed that the API will remain backwards compatible
// in minor releases (2.x)

// gtkui plugin id has been changed to gtkui_1, to avoid loading broken plugins.
// please DON'T simply patch your plugin to load gtkui_1 instead of gtkui.
// for information, about how to port your plugin to the new API correctly,
// and to learn more about design mode programming,
// please visit the following page:
// http://github.com/Alexey-Yakovenko/deadbeef/wiki/Porting-GUI-plugins-to-deadbeef-from-0.5.x-to-0.6.0

enum DDB_GTKUI_PLUGIN_ID = "gtkui3_1";

enum DDB_GTKUI_API_VERSION_MAJOR = 2;
enum DDB_GTKUI_API_VERSION_MINOR = 2;

// avoid including glibc headers, this is not very portable
extern (D) auto __GNUC_PREREQ(T0, T1)(auto ref T0 maj, auto ref T1 min)
{
    return (__GNUC__ << 16) + __GNUC_MINOR__ >= (maj << 16) + min;
}

enum DDB_GTKUI_API_LEVEL = DDB_GTKUI_API_VERSION_MAJOR * 100;// + DB_API_VERSION_MINOR;

// added in API 2.1 (deadbeef-0.6.2)
enum DDB_GTKUI_CONF_LAYOUT = "gtkui.layout.0.6.2";

// this flag tells that the widget should be added to h/vboxes with expand=FALSE
enum DDB_GTKUI_WIDGET_FLAG_NON_EXPANDABLE = 0x00000001;

// widget config string must look like that:
// type key1=value1 key2=value2... { child widgets }
//
// the default widget loader will ignore all key-value pairs,
// so it's your custom loader's responsibility to handle them
// you can find out how to write custom loaders in gtkui sources,
// look e.g. for the "w_splitter_load"

struct ddb_gtkui_widget_s
{
    const(char)* type;

    ddb_gtkui_widget_s* parent;

    GtkWidget* widget;

    uint flags;

    // all the functions here are overloads, so they are not mandatory
    // they can be implemented to add custom code to normal widget code
    // they can be NULL if you don't need them, or you can set them to
    // standard functions (more below)

    // this function will be called after the widget is visible and needs to
    // [re]initialize itself
    // e.g. splitter widget sets the grip position in the init
    void function (ddb_gtkui_widget_s* container) init;

    // save your custom parameters in the string using strncat
    // for example, if you need to write width and height:
    // strncat (s, "100 200", sz);
    void function (ddb_gtkui_widget_s* w, char* s, int sz) save;

    // this is to read custom widget parameters, e.g. width and height;
    // you will be passed a string looking like "100 200 {"
    // you will need to read params, and return the new pointer, normally it
    // should be pointing to the "{"
    //
    // type string is necessary for backwards compatibility, so that load
    // function knows which type it's loading
    const(char)* function (ddb_gtkui_widget_s* w, const(char)* type, const(char)* s) load;

    // custom destructor code
    void function (ddb_gtkui_widget_s* w) destroy;

    // custom append code
    // if left NULL, appending will not be supported
    // you should use standard w_container_add if your widget is derived from
    // GTK_CONTAINER
    void function (ddb_gtkui_widget_s* container, ddb_gtkui_widget_s* child) append;

    // custom remove code
    // you should use w_container_remove if your widget is derived from
    // GTK_CONTAINER
    void function (ddb_gtkui_widget_s* container, ddb_gtkui_widget_s* child) remove;

    // custom replace code
    // default replace will call remove;destroy;append
    // but you can override if you need smarter behaviour
    // look at the splitter and tabs implementation for more details
    void function (ddb_gtkui_widget_s* container, ddb_gtkui_widget_s* child, ddb_gtkui_widget_s* newchild) replace;

    // return the container widget of a composite widget
    // e.g. HBox is contained in EventBox, this function should return the HBox
    // the default implementation will always return the toplevel widget
    GtkWidget* function (ddb_gtkui_widget_s* w) get_container;

    // implement this if you want to handle deadbeef broadcast messages/events
    int function (ddb_gtkui_widget_s* w, uint id, uintptr_t ctx, uint p1, uint p2) message;

    // this will be called to setup the menu widget in design mode
    void function (ddb_gtkui_widget_s* w, GtkWidget* menu) initmenu;

    // this will be called to setup the child menu widget in design mode
    // for example, to add "expand"/"fill" options for hbox/vbox children
    void function (ddb_gtkui_widget_s* w, GtkWidget* menu) initchildmenu;

    // you shouldn't touch this list normally, the system takes care of it
    ddb_gtkui_widget_s* children;
    ddb_gtkui_widget_s* next; // points to next widget in the same container
}

alias ddb_gtkui_widget_t = ddb_gtkui_widget_s;

// flags for passing to w_reg_widget

// tell the widget manager, that this widget can only have single instance
enum DDB_WF_SINGLE_INSTANCE = 0x00000001;

struct ddb_gtkui_t
{
    DB_gui_t gui;

    // returns main window ptr
    GtkWidget* function () get_mainwin;

    // register new widget type;
    // type strings are passed at the end of argument list terminated with NULL
    // for example:
    // w_reg_widget("My Visualization", 0, my_viz_create, "my_viz_ng", "my_viz", NULL);
    // this call will register new type "my_viz_ng", with support for another
    // "my_viz" type string
    void function (const(char)* title, uint flags, ddb_gtkui_widget_t* function () create_func, ...) w_reg_widget;

    // unregister existing widget type
    void function (const(char)* type) w_unreg_widget;

    // this must be called from your <widget>_create for design mode support
    //void function (GtkWidget* w, gpointer user_data) w_override_signals;

    // returns 1 if a widget of specified type is registered
    int function (const(char)* type) w_is_registered;

    // returns the toplevel widget
    ddb_gtkui_widget_t* function () w_get_rootwidget;

    // enter/exit design mode
    void function (int active) w_set_design_mode;

    // check whether we are in design mode
    int function () w_get_design_mode;

    // create a widget of specified type
    ddb_gtkui_widget_t* function (const(char)* type) w_create;

    // destroy the widget
    void function (ddb_gtkui_widget_t* w) w_destroy;

    // append the widget to the container
    void function (ddb_gtkui_widget_t* cont, ddb_gtkui_widget_t* child) w_append;

    // replace existing child widget in the container with another widget
    void function (ddb_gtkui_widget_t* w, ddb_gtkui_widget_t* from, ddb_gtkui_widget_t* to) w_replace;

    // remove the widget from its container
    void function (ddb_gtkui_widget_t* cont, ddb_gtkui_widget_t* child) w_remove;

    // return the container widget of a composite widget
    // e.g. HBox is contained in EventBox, this function should return the HBox
    // the default implementation will always return the toplevel widget
    GtkWidget* function (ddb_gtkui_widget_t* w) w_get_container;

    // function to create the standard playlist context menu (the same as
    // appears when right-clicked on playlist tab)
    GtkWidget* function (int plt_idx) create_pltmenu;

    // return a cover art pixbuf, if available.
    // if not available, the requested cover will be loaded asyncronously.
    // the callback will be called when the requested cover is available,
    // in which case you will need to call the get_cover_art_pixbuf again from
    // the callback.
    // get_cover_art_pixbuf is deprecated in API 2.2.
    // in new code, use get_cover_art_primary to get the large single cover art image,
    // and get_cover_art_thumb to get one of many smaller cover art images.
    GdkPixbuf* function (const(char)* uri, const(char)* artist, const(char)* album, int size, void function (void* user_data) callback, void* user_data) get_cover_art_pixbuf;

    // get_default_cover_pixbuf returns the default cover art image
    GdkPixbuf* function () cover_get_default_pixbuf;

    // added in API 2.2 (deadbeef-0.7)
    GdkPixbuf* function (const(char)* uri, const(char)* artist, const(char)* album, int size, void function (void* user_data) callback, void* user_data) get_cover_art_primary;
    GdkPixbuf* function (const(char)* uri, const(char)* artist, const(char)* album, int size, void function (void* user_data) callback, void* user_data) get_cover_art_thumb;
    // adds a hook to be called before the main loop starts running, but after
    // the window was created.
    void function (void function (void* userdata) callback, void* userdata) add_window_init_hook;
}
