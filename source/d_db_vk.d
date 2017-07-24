module d_db_vk;

import std.uni;
import core.runtime;
import core.thread;
import std.path, std.conv, std.regex, std.json, std.stdio, std.string;
import deadbeefl;
import gtk.c.functions;
import gtk.c.types;
import glib.c.functions;
import gdk.c.functions;
import gobject.c.functions;
import requests;
import gtkui_api;
import arsd.characterencodings;
import vk_api;

extern (C):

__gshared DB_functions_t* deadbeef;
static DB_vfs_t plugin;

static ddb_gtkui_t* gtkui_plugin;
static DB_vfs_t* vfs_curl_plugin;

static int vk_start() {
    writeln("vk_start");
    return 0;
}

static int vk_stop() {
    writeln("vk_stop");
    return 0;
}
const(char)* s = `
property "Username" entry dvk.login "";
property "Password" password dvk.password "";
property "Download cover" checkbox dvk.download_cover 1;
`;

struct AudioObject { 
    int aid;
    int oid;
    string title;
    string artist;
    string formatted_duration;
    int duration;
}

void add_to_list(void* data, JSONValue object) {
    GtkTreeIter iter;
    gtk_list_store_append(cast(GtkListStore*)data, &iter);
    import std.xml : decode;
    gtk_list_store_set (cast(GtkListStore*)data, &iter,
                            0, object[4].str.decode.toStringz,
                            1, object[3].str.decode.toStringz,
                            2, to!int(object[5].integer),
                            3, "%d:%02d".format(object[5].integer / 60, object[5].integer % 60).toStringz,
                            4, "url".toStringz,
                            5, to!int(object[0].integer),
                            6, to!int(object[1].integer),
                            7, object[14].str.toStringz,
                            8, HQ_formatted(object[10].integer).toStringz,
                            -1);
}

static int on_search (GtkWidget *widget, void* data) {
    gtk_widget_set_sensitive (widget, false);
    string query_text = cast(string)gtk_entry_get_text (cast(GtkEntry*) widget).fromStringz;
    gtk_list_store_clear(cast(GtkListStore*)data);

    try {
        JSONValue[] list;
        if (query_text.startsWith("https://vk.com")) {
            list = vk_get_by_id(query_text);
        } else {
            list = vk_search_request(query_text);
        }
        foreach (e; list) {
            add_to_list(data, e);
        }
    } catch(Throwable o) {
        writeln(o);
    }
    gtk_widget_set_sensitive(widget, true);
    gtk_widget_grab_focus(widget);
    return 1;
}

static void on_search_target_changed (GtkWidget *widget, void* data) {
    search_target_id = gtk_combo_box_get_active(cast(GtkComboBox*)widget);
}

static GtkCellRenderer* vk_gtk_cell_renderer_text_new_with_ellipsis() {
    GtkCellRenderer *renderer = gtk_cell_renderer_text_new ();
    g_object_set(renderer, toStringz("ellipsize"), PangoEllipsizeMode.END, null);
    return renderer;
}



static void on_my_music (GtkWidget *widget, void* data) {
    gtk_widget_set_sensitive (widget, false);

    gtk_list_store_clear(cast(GtkListStore*)data);

    try {
        auto list = vk_my_music_request();
        foreach (e; list) {
            add_to_list(data, e);
        }
    } catch(Throwable o) {
        writeln(o);
    }
    gtk_widget_set_sensitive(widget, true);
}

static void on_suggested_music(GtkWidget* widget, void* data) {
    gtk_widget_set_sensitive (widget, false);

    gtk_list_store_clear(cast(GtkListStore*)data);

    try {
        auto list = vk_suggested_request();
        foreach (e; list) {
            add_to_list(data, e);
        }
    } catch(Throwable o) {
        writeln(o);
    }
    gtk_widget_set_sensitive(widget, true);
}

void vk_add_tracks_from_tree_model_to_playlist (GtkTreeModel *treemodel, GList *gtk_tree_path_list, const char *plt_name) {
    try {
        deadbeef_api.conf_lock();

        bool download_cover = to!bool(deadbeef_api.conf_get_int("dvk.download_cover".toStringz, 1));

        deadbeef_api.conf_unlock();

        ddb_playlist_t* plt = deadbeef.plt_get_curr();
        if (!deadbeef.plt_add_files_begin(plt, 0)) {
            DB_playItem_t* last = deadbeef.plt_get_last(plt, 0);

            gtk_tree_path_list = g_list_last(gtk_tree_path_list);
            while (gtk_tree_path_list) {
                GtkTreeIter iter;
                char* artist, title, covers;
                int duration, aid, owner_id;
                if (gtk_tree_model_get_iter(treemodel, &iter, cast(GtkTreePath*)gtk_tree_path_list.data)) {
                    gtk_tree_model_get (treemodel, &iter,
                                    0, &artist,
                                    1, &title,
                                    2, &duration,
                                    5, &aid,
                                    6, &owner_id,
                                    7, &covers,
                                    -1);
                    int pabort = 0;
                    DB_playItem_t *pt = deadbeef.plt_insert_file2(0, plt, last, "dvk://%s_%s".format(owner_id, aid).toStringz, &pabort, null, null);
                    deadbeef.pl_add_meta(pt, "artist".toStringz, artist);
                    deadbeef.pl_add_meta(pt, "title".toStringz, title);
                    deadbeef.plt_set_item_duration(plt, pt, duration);
                    if(download_cover) {
                        string sdir = to!string(deadbeef.get_system_dir(ddb_sys_directory_t.DDB_SYS_DIR_CACHE));
                        string dir = buildPath(sdir, "covers", to!string(artist));
                        string full_path = buildPath(dir, "%s.jpg".format(to!string(title)));
                        string cover = to!string(covers);
                        if(cover) {
                            import std.file : mkdirRecurse, write;
                            mkdirRecurse(dir);
                            string max_cover = cover.split(",")[1].strip();
                            auto content = getContent(max_cover);
                            write(full_path, content.data);
                        }
                    }
                    gtk_tree_path_list = gtk_tree_path_list.prev;
                }
            }
            if (last) {
                deadbeef.pl_item_unref(last);
            }
        }
        deadbeef.plt_add_files_end (plt, 0);
        deadbeef.plt_save_config (plt);
        deadbeef.plt_unref (plt);
    } catch(Throwable e) {
        writeln(e);
    }
}

static void add_to_playlist (GtkTreeView *tree_view, const char *playlist) {
    GtkTreeSelection *selection;
    GtkTreeModel *treemodel;
    GList *selected_rows;

    selection = gtk_tree_view_get_selection (tree_view);
    selected_rows = gtk_tree_selection_get_selected_rows (selection, &treemodel);

    vk_add_tracks_from_tree_model_to_playlist (treemodel, selected_rows, playlist);

    g_list_free (selected_rows);
}

static void on_search_results_row_activate (GtkTreeView *tree_view, GtkTreePath *path, GtkTreeViewColumn *column, void* user_data) {
    //add_to_playlist (tree_view, NULL);
    //writeln("clicked item");
    add_to_playlist (tree_view, null);
}

int vk_action_gtk(void *data) {
    GtkWidget *dlg_vbox = gtk_box_new (GtkOrientation.VERTICAL, 0);

    GtkListStore *list_store = gtk_list_store_new (cast(int)9,
                                     GType.STRING,     // ARTIST
                                     GType.STRING,     // TITLE
                                     GType.INT,        // DURATION seconds, not rendered
                                     GType.STRING,     // DURATION_FORMATTED
                                     GType.STRING,     // URL, not rendered
                                     GType.INT,        // AID, not rendered
                                     GType.INT,        // OWNER_ID, not rendered
                                     GType.STRING,     // COVERS, not rendered
                                     GType.STRING      // QUALITY
                                     );

    GtkWidget *search_hbox = gtk_box_new(GtkOrientation.HORIZONTAL, 12);
    gtk_box_pack_start (cast(GtkBox*)dlg_vbox, search_hbox, false, false, 0);

    GtkWidget* search_text = gtk_entry_new ();
    gtk_widget_show (search_text);
    g_signal_connect_data(search_text, toStringz("activate"), cast(GCallback)&on_search, list_store, null, GConnectFlags.AFTER);
    gtk_box_pack_start(cast(GtkBox*)search_hbox, search_text, true, true, 0);


    GtkWidget* search_target = gtk_combo_box_text_new();
    // must to order of VkSearchTarget entries
    gtk_combo_box_text_append_text(cast(GtkComboBoxText*)search_target, toStringz("Title"));
    gtk_combo_box_text_append_text(cast(GtkComboBoxText*)search_target, toStringz("Artist"));
    gtk_combo_box_set_active(cast(GtkComboBox*)search_target, 0);
    g_signal_connect_data(search_target, toStringz("changed"), cast(GCallback)&on_search_target_changed, list_store, null, GConnectFlags.AFTER);
    gtk_box_pack_start(cast(GtkBox*)search_hbox, search_target, false, false, 0);

    GtkWidget* search_results = gtk_tree_view_new_with_model (cast(GtkTreeModel*)list_store);
    gtk_tree_view_insert_column_with_attributes(cast(GtkTreeView*)search_results, -1, toStringz("Artist"),
                                                 vk_gtk_cell_renderer_text_new_with_ellipsis,
                                                 toStringz("text"), 0, null);
    gtk_tree_view_insert_column_with_attributes(cast(GtkTreeView*)search_results, -1, toStringz("Title"),
                                                 vk_gtk_cell_renderer_text_new_with_ellipsis,
                                                 toStringz("text"), 1, null);
    gtk_tree_view_insert_column_with_attributes(cast(GtkTreeView*)search_results, -1, toStringz("Duration"),
                                                 gtk_cell_renderer_text_new (),
                                                 toStringz("text"), 3, null);
    gtk_tree_view_insert_column_with_attributes(cast(GtkTreeView*)search_results, -1, toStringz("Quality"),
                                                 gtk_cell_renderer_text_new (),
                                                 toStringz("text"), 8, null);
    GtkTreeViewColumn *col;
    // artist col is resizeable and sortable
    col = gtk_tree_view_get_column (cast(GtkTreeView*)search_results, 0);
    g_object_set (col,
                  toStringz("sizing"), GtkTreeViewColumnSizing.FIXED,
                  toStringz("resizable"), true,
                  toStringz("expand"), true,
                  toStringz("sort-column-id"), 0,
                  null);

    col = gtk_tree_view_get_column (cast(GtkTreeView*)search_results, 1);
    g_object_set (col,
                  toStringz("sizing"), GtkTreeViewColumnSizing.FIXED,
                  toStringz("resizable"), true,
                  toStringz("expand"), true,
                  toStringz("sort-column-id"), 1,
                  null);
    // duration col is sortable and fixed width
    col = gtk_tree_view_get_column (cast(GtkTreeView*)search_results, 2);
    g_object_set(col,
                  toStringz("sizing"), GtkTreeViewColumnSizing.FIXED,
                  toStringz("resizable"), true,
                  toStringz("min-width"), 20,
                  toStringz("max-width"), 70,
                  toStringz("fixed-width"), 50,
                  toStringz("sort-column-id"), 2,
                  null);

    gtk_tree_selection_set_mode (gtk_tree_view_get_selection (cast(GtkTreeView*)search_results), GtkSelectionMode.MULTIPLE);

    g_signal_connect_data(search_results, toStringz("row-activated"), cast(GCallback)&on_search_results_row_activate, null, null, GConnectFlags.AFTER);
    g_signal_connect_data(search_results, toStringz("popup-menu"), cast(GCallback)&on_search_results_popup_menu, null, null, GConnectFlags.AFTER);
    //dirty hack
    g_signal_connect_data(search_results, toStringz("button-press-event"), cast(GCallback)&on_search_results_button_press, search_results, null, GConnectFlags.SWAPPED);

    GtkWidget* scroll_window = gtk_scrolled_window_new (null, null);
    gtk_scrolled_window_set_policy (cast(GtkScrolledWindow*)scroll_window, GtkPolicyType.AUTOMATIC, GtkPolicyType.AUTOMATIC);
    gtk_container_add (cast(GtkContainer*)scroll_window, search_results);
    gtk_box_pack_start (cast(GtkBox*)dlg_vbox, scroll_window, true, true, 12);
    
    GtkWidget* bottom_hbox = gtk_box_new(GtkOrientation.HORIZONTAL, 12);
    gtk_box_pack_start(cast(GtkBox*)dlg_vbox, bottom_hbox, false, true, 0);
    
    GtkWidget* my_music_button = gtk_button_new_with_label ("My music");
    g_signal_connect_data(my_music_button, "clicked".toStringz, cast(GCallback)&on_my_music, list_store, null, GConnectFlags.AFTER);
    gtk_box_pack_start (cast(GtkBox*)bottom_hbox, my_music_button, false, false, 0);
    
    GtkWidget* recommendations_button = gtk_button_new_with_label ("Recommended");
    g_signal_connect_data(recommendations_button, "clicked".toStringz, cast(GCallback)&on_suggested_music, list_store, null, GConnectFlags.AFTER);
    gtk_box_pack_start (cast(GtkBox*)bottom_hbox, recommendations_button, false, false, 0);

    
    gtk_widget_show_all (dlg_vbox);



    /////

    GtkWidget* add_tracks_dlg;
    GtkWidget* dlg_vbox_;

    add_tracks_dlg = gtk_dialog_new_with_buttons (
            toStringz("Search tracks"),
            cast(GtkWindow*)gtkui_plugin.get_mainwin (),
            GtkDialogFlags.DESTROY_WITH_PARENT,
            null,
            null);
    gtk_container_set_border_width (cast(GtkContainer*) add_tracks_dlg, 12);
    gtk_window_set_default_size (cast(GtkWindow*) add_tracks_dlg, 840, 400);
    dlg_vbox_ = gtk_dialog_get_content_area (cast(GtkDialog*) add_tracks_dlg);
    //gtk_box_pack_start (GTK_BOX (dlg_vbox), vk_create_browser_widget_content (), TRUE, TRUE, 0);
    gtk_box_pack_start (cast(GtkBox*)dlg_vbox_, dlg_vbox, true, true, 0);
    gtk_widget_show (add_tracks_dlg);

    return 0;
}

static void on_menu_item_add_to_playlist(GtkWidget *menu_item, GtkTreeView *tree_view) {
    add_to_playlist(tree_view, null);
}

static void show_popup_menu (GtkTreeView *treeview, GdkEventButton *event) {
    GtkTreeSelection *selection;
    GtkWidget* menu, item;

    selection = gtk_tree_view_get_selection(treeview);
    if (!gtk_tree_selection_count_selected_rows(selection)) {
        // don't show menu on empty tree view
        return;
    }

    menu = gtk_menu_new ();

    item = gtk_menu_item_new_with_label ("Add to current playlist");
    g_signal_connect_data(item, "activate".toStringz, cast(GCallback)&on_menu_item_add_to_playlist, treeview, null, GConnectFlags.AFTER);
    gtk_menu_shell_append (cast(GtkMenuShell*)menu, item);

    //item = gtk_menu_item_new_with_label ("Copy URL(s)");
    //g_signal_connect (item, "activate", G_CALLBACK (on_menu_item_copy_url), treeview);
    //gtk_menu_shell_append(cast(GtkMenuShell*)menu, item);

    gtk_widget_show_all(menu);
    gtk_menu_popup(cast(GtkMenu*)menu, null, null, null, null, 0, gdk_event_get_time(cast(GdkEvent*) event));
}

static int on_search_results_button_press(GtkTreeView *treeview, GdkEventButton *event, void* userdata) {
    if (!gtkui_plugin.w_get_design_mode() && event.type == GdkEventType.BUTTON_PRESS && event.button == 3) {
        GtkTreeView* tv = cast(GtkTreeView*)userdata;
        GtkTreeSelection *selection;

        selection = gtk_tree_view_get_selection (tv);
        if (gtk_tree_selection_count_selected_rows(selection) <= 1) {
            GtkTreePath *path;
            if (gtk_tree_view_get_path_at_pos(tv, cast(int)event.x, cast(int)event.y, &path, null, null, null )) {
                gtk_tree_selection_unselect_all(selection);
                gtk_tree_selection_select_path (selection, path);
                gtk_tree_path_free (path);
            }
        }

        show_popup_menu(treeview, event);
        return 1;
    }
    return 0;
}

static int on_search_results_popup_menu(GtkTreeView *treeview, void* userdata) {
    show_popup_menu(treeview, null);
    return 1;
}

static int vk_ddb_action_callback(DB_plugin_action_t *action, int ctx) {
    g_idle_add(&vk_action_gtk, null);
    return 0;
}

static DB_plugin_action_t* vk_ddb_get_actions(DB_playItem_t *it) {
    static DB_plugin_action_t vk_ddb_action;

    vk_ddb_action.title = "File/Add tracks";
    vk_ddb_action.name = "vk_dd_tracks";
    vk_ddb_action.flags = DB_ACTION_COMMON | DB_ACTION_ADD_MENU;
    vk_ddb_action.callback2 = cast(DB_plugin_action_callback2_t) &vk_ddb_action_callback;
    vk_ddb_action.next = null;
    return &vk_ddb_action;
}

static int vk_ddb_connect () {
    vfs_curl_plugin = cast(DB_vfs_t*) deadbeef.plug_get_for_id ("vfs_curl");
    if (!vfs_curl_plugin) {
        writeln("cURL VFS plugin required\n");
        return -1;
    }

    gtkui_plugin = cast(ddb_gtkui_t*)deadbeef.plug_get_for_id (DDB_GTKUI_PLUGIN_ID);
    if (gtkui_plugin && gtkui_plugin.gui.plugin.version_major == 2) {  // gtkui version 2
        initAPI(deadbeef);
        writeln("connect");
        return 0;
    }
    return -1;
}

static vk_ddb_disconnect() {
    writeln("disconnect");
    return 0;
}

public static char** toStringzArray(string[] args)
{
    if ( args is null )
    {
        return null;
    }
    char** argv = (new char*[args.length]).ptr;
    int argc = 0;
    foreach (string p; args)
    {
        argv[argc++] = cast(char*)(p.dup~'\0');
    }
    argv[argc] = null;

    return argv;
}

const(char*)* vk_ddb_vfs_get_schemes () {
	return toStringzArray(["dvk://"]);
}
static int vk_ddb_vfs_is_streaming() {
    return 1;
}

DB_FILE* vk_ddb_vfs_open (const(char)*fname) {
    DB_FILE* f;
    string id = cast(string)(fname.fromStringz).replace("dvk://", "");
    f = deadbeef.fopen(vk_open_request(id).toStringz);
    return f;
}

DB_plugin_t* d_db_vk_load(DB_functions_t* api){
    import core.exception;

    Runtime.initialize();
    plugin.plugin.id = "dvk";
    plugin.plugin.api_vmajor = 1;
    plugin.plugin.api_vminor = 5;
    plugin.plugin.version_major = 0;
    plugin.plugin.version_minor = 1;
    plugin.plugin.type = DB_PLUGIN_VFS;
    plugin.plugin.name = "VK";
    plugin.plugin.descr = "Play music from VKontakte social network site.\n";
    plugin.plugin.website = "https://ga2mer.github.io/";
    plugin.plugin.configdialog = s;
    plugin.plugin.connect = &vk_ddb_connect,
    plugin.plugin.disconnect = &vk_ddb_disconnect,
    plugin.plugin.start = &vk_start;
    plugin.plugin.stop = &vk_stop;
    plugin.plugin.get_actions = &vk_ddb_get_actions;
    plugin.get_schemes = &vk_ddb_vfs_get_schemes;
    plugin.is_streaming = &vk_ddb_vfs_is_streaming;
    plugin.open = &vk_ddb_vfs_open;
    deadbeef = api;
    return DB_PLUGIN(&plugin);
}
