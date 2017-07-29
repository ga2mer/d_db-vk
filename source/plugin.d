module plugin;

import core.runtime;
import core.thread;
import std.path, std.conv, std.regex, std.json, std.stdio, std.string;
import db;
import gtk.c.functions;
import gtk.c.types;
import glib.c.functions;
import gdk.c.functions;
import gobject.c.functions;
import requests;
import gtkui_api;
import arsd.characterencodings;
import ui;
import vkapi;

extern (C):

__gshared DB_functions_t* deadbeef;
static DB_vfs_t plugin;

static ddb_gtkui_t* gtkUIPlugin;
static DB_vfs_t* vfs_curl_plugin;

static int vkStart() {
    writeln("vk_start");
    return 0;
}

static int vkStop() {
    writeln("vk_stop");
    return 0;
}
const(char)* configDialog = `
property "Username" entry dvk.login "";
property "Password" password dvk.password "";
property "Download cover" checkbox dvk.download_cover 1;
`;
//k_add_tracks_from_tree_model_to_playlist
void vkAddTracksFromTreeModelToPlaylist (GtkTreeModel *treemodel, GList *gtk_tree_path_list, const char *plt_name) {
    try {
        deadbeef.conf_lock();

        bool downloadCover = to!bool(deadbeef.conf_get_int("dvk.download_cover".toStringz, 1));

        deadbeef.conf_unlock();

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
                    if(downloadCover) {
                        string sdir = to!string(deadbeef.get_system_dir(ddb_sys_directory_t.DDB_SYS_DIR_CACHE));
                        string dir = buildPath(sdir, "covers", to!string(artist));
                        string fullPath = buildPath(dir, "%s.jpg".format(to!string(title)));
                        string cover = to!string(covers);
                        if(cover) {
                            import std.file : mkdirRecurse, write;
                            mkdirRecurse(dir);
                            string max_cover = cover.split(",")[1].strip();
                            auto content = getContent(max_cover);
                            write(fullPath, content.data);
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

static int pluginActionCallback(DB_plugin_action_t *action, int ctx) {
    g_idle_add(&pluginActionGtk, null);
    return 0;
}

static DB_plugin_action_t* pluginGetActions(DB_playItem_t *it) {
    static DB_plugin_action_t vk_ddb_action;

    vk_ddb_action.title = "File/Add tracks";
    vk_ddb_action.name = "vk_dd_tracks";
    vk_ddb_action.flags = DB_ACTION_COMMON | DB_ACTION_ADD_MENU;
    vk_ddb_action.callback2 = cast(DB_plugin_action_callback2_t) &pluginActionCallback;
    vk_ddb_action.next = null;
    return &vk_ddb_action;
}

static int pluginConnect () {
    vfs_curl_plugin = cast(DB_vfs_t*) deadbeef.plug_get_for_id ("vfs_curl");
    if (!vfs_curl_plugin) {
        writeln("cURL VFS plugin required\n");
        return -1;
    }

    gtkUIPlugin = cast(ddb_gtkui_t*)deadbeef.plug_get_for_id (DDB_GTKUI_PLUGIN_ID);
    if (gtkUIPlugin && gtkUIPlugin.gui.plugin.version_major == 2) {  // gtkui version 2
        writeln("connect");
        return 0;
    }
    return -1;
}

int pluginDisconnect() {
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

const(char*)* pluginVFSGetSchemes () {
	return toStringzArray(["dvk://"]);
}
static int pluginIsStreaming() {
    return 1;
}

DB_FILE* pluginVFSOpen (const(char)*fname) {
    DB_FILE* file;
    string id = cast(string)(fname.fromStringz).replace("dvk://", "");
    file = deadbeef.fopen(vkOpenRequest(id).toStringz);
    return file;
}

DB_plugin_t* d_db_vk_gtk3_load(DB_functions_t* api){
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
    plugin.plugin.configdialog = configDialog;
    plugin.plugin.connect = &pluginConnect,
    plugin.plugin.disconnect = &pluginDisconnect,
    plugin.plugin.start = &vkStart;
    plugin.plugin.stop = &vkStop;
    plugin.plugin.get_actions = &pluginGetActions;
    plugin.get_schemes = &pluginVFSGetSchemes;
    plugin.is_streaming = &pluginIsStreaming;
    plugin.open = &pluginVFSOpen;
    deadbeef = api;
    return DB_PLUGIN(&plugin);
}
