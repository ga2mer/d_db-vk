module ui;

import std.conv, std.string, std.json, std.stdio;

import gtk.c.functions;
import gtk.c.types;
import glib.c.functions;
import gdk.c.functions;
import gobject.c.functions;

import plugin;
import vkapi;
import gtkui_api;

extern (C):

void addToList(void* data, JSONValue object) {
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
                            8, formattedHQ(object[10].integer).toStringz,
                            -1);
}

static int onSearch (GtkWidget *widget, void* data) {
    gtk_widget_set_sensitive (widget, false);
    string queryText = cast(string)gtk_entry_get_text (cast(GtkEntry*) widget).fromStringz;
    gtk_list_store_clear(cast(GtkListStore*)data);

    try {
        JSONValue[] list;
        if (queryText.startsWith("https://vk.com")) {
            list = vkGetById(queryText);
        } else {
            list = vkSearchRequest(queryText);
        }
        foreach (e; list) {
            addToList(data, e);
        }
    } catch(Throwable o) {
        writeln(o);
    }
    gtk_widget_set_sensitive(widget, true);
    gtk_widget_grab_focus(widget);
    return 1;
}

static void onSearchTargetChanged (GtkWidget *widget, void* data) {
    searchTargetId = gtk_combo_box_get_active(cast(GtkComboBox*)widget);
}
static GtkCellRenderer* gtkCellRendererTextNewWithEllipsis() {
    GtkCellRenderer *renderer = gtk_cell_renderer_text_new ();
    g_object_set(renderer, toStringz("ellipsize"), PangoEllipsizeMode.END, null);
    return renderer;
}



static void onMyMusic (GtkWidget *widget, void* data) {
    gtk_widget_set_sensitive (widget, false);

    gtk_list_store_clear(cast(GtkListStore*)data);

    try {
        auto list = vkMyMusicRequest();
        foreach (e; list) {
            addToList(data, e);
        }
    } catch(Throwable o) {
        writeln(o);
    }
    gtk_widget_set_sensitive(widget, true);
}

static void onSuggestedMusic(GtkWidget* widget, void* data) {
    gtk_widget_set_sensitive (widget, false);

    gtk_list_store_clear(cast(GtkListStore*)data);

    try {
        auto list = vkSuggestedRequest();
        foreach (e; list) {
            addToList(data, e);
        }
    } catch(Throwable o) {
        writeln(o);
    }
    gtk_widget_set_sensitive(widget, true);
}

static void addToPlaylist (GtkTreeView *tree_view, const char *playlist) {
    GtkTreeSelection *selection;
    GtkTreeModel *treemodel;
    GList *selected_rows;

    selection = gtk_tree_view_get_selection (tree_view);
    selected_rows = gtk_tree_selection_get_selected_rows (selection, &treemodel);

    vkAddTracksFromTreeModelToPlaylist (treemodel, selected_rows, playlist);

    g_list_free (selected_rows);
}

static void on_search_results_row_activate (GtkTreeView *tree_view, GtkTreePath *path, GtkTreeViewColumn *column, void* user_data) {
    addToPlaylist (tree_view, null);
}

int pluginActionGtk(void* data) {
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
    g_signal_connect_data(search_text, toStringz("activate"), cast(GCallback)&onSearch, list_store, null, GConnectFlags.AFTER);
    gtk_box_pack_start(cast(GtkBox*)search_hbox, search_text, true, true, 0);


    GtkWidget* search_target = gtk_combo_box_text_new();
    // must to order of VkSearchTarget entries
    gtk_combo_box_text_append_text(cast(GtkComboBoxText*)search_target, toStringz("Title"));
    gtk_combo_box_text_append_text(cast(GtkComboBoxText*)search_target, toStringz("Artist"));
    gtk_combo_box_set_active(cast(GtkComboBox*)search_target, 0);
    g_signal_connect_data(search_target, toStringz("changed"), cast(GCallback)&onSearchTargetChanged, list_store, null, GConnectFlags.AFTER);
    gtk_box_pack_start(cast(GtkBox*)search_hbox, search_target, false, false, 0);

    GtkWidget* search_results = gtk_tree_view_new_with_model (cast(GtkTreeModel*)list_store);
    gtk_tree_view_insert_column_with_attributes(cast(GtkTreeView*)search_results, -1, toStringz("Artist"),
                                                 gtkCellRendererTextNewWithEllipsis,
                                                 toStringz("text"), 0, null);
    gtk_tree_view_insert_column_with_attributes(cast(GtkTreeView*)search_results, -1, toStringz("Title"),
                                                 gtkCellRendererTextNewWithEllipsis,
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
    g_signal_connect_data(search_results, toStringz("popup-menu"), cast(GCallback)&onSearchResultsPopupMenu, null, null, GConnectFlags.AFTER);
    //dirty hack
    g_signal_connect_data(search_results, toStringz("button-press-event"), cast(GCallback)&onSearchResultsButtonPress, search_results, null, GConnectFlags.SWAPPED);

    GtkWidget* scroll_window = gtk_scrolled_window_new (null, null);
    gtk_scrolled_window_set_policy (cast(GtkScrolledWindow*)scroll_window, GtkPolicyType.AUTOMATIC, GtkPolicyType.AUTOMATIC);
    gtk_container_add (cast(GtkContainer*)scroll_window, search_results);
    gtk_box_pack_start (cast(GtkBox*)dlg_vbox, scroll_window, true, true, 12);
    
    GtkWidget* bottom_hbox = gtk_box_new(GtkOrientation.HORIZONTAL, 12);
    gtk_box_pack_start(cast(GtkBox*)dlg_vbox, bottom_hbox, false, true, 0);
    
    GtkWidget* my_music_button = gtk_button_new_with_label ("My music");
    g_signal_connect_data(my_music_button, "clicked".toStringz, cast(GCallback)&onMyMusic, list_store, null, GConnectFlags.AFTER);
    gtk_box_pack_start (cast(GtkBox*)bottom_hbox, my_music_button, false, false, 0);
    
    GtkWidget* recommendations_button = gtk_button_new_with_label ("Recommended");
    g_signal_connect_data(recommendations_button, "clicked".toStringz, cast(GCallback)&onSuggestedMusic, list_store, null, GConnectFlags.AFTER);
    gtk_box_pack_start (cast(GtkBox*)bottom_hbox, recommendations_button, false, false, 0);

    
    gtk_widget_show_all (dlg_vbox);



    /////

    GtkWidget* add_tracks_dlg;
    GtkWidget* dlg_vbox_;

    add_tracks_dlg = gtk_dialog_new_with_buttons (
            toStringz("Search tracks"),
            cast(GtkWindow*)gtkUIPlugin.get_mainwin (),
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

static void onMenuItemAddToPlaylist(GtkWidget *menuItem, GtkTreeView *treeView) {
    addToPlaylist(treeView, null);
}

static void showPopupMenu (GtkTreeView *treeView, GdkEventButton *event) {
    GtkTreeSelection *selection;
    GtkWidget* menu, item;

    selection = gtk_tree_view_get_selection(treeView);
    if (!gtk_tree_selection_count_selected_rows(selection)) {
        // don't show menu on empty tree view
        return;
    }

    menu = gtk_menu_new ();

    item = gtk_menu_item_new_with_label ("Add to current playlist");
    g_signal_connect_data(item, "activate".toStringz, cast(GCallback)&onMenuItemAddToPlaylist, treeView, null, GConnectFlags.AFTER);
    gtk_menu_shell_append (cast(GtkMenuShell*)menu, item);

    //item = gtk_menu_item_new_with_label ("Copy URL(s)");
    //g_signal_connect (item, "activate", G_CALLBACK (on_menu_item_copy_url), treeview);
    //gtk_menu_shell_append(cast(GtkMenuShell*)menu, item);

    gtk_widget_show_all(menu);
    gtk_menu_popup(cast(GtkMenu*)menu, null, null, null, null, 0, gdk_event_get_time(cast(GdkEvent*) event));
}

static int onSearchResultsButtonPress(GtkTreeView *treeview, GdkEventButton *event, void* userdata) {
    if (!gtkUIPlugin.w_get_design_mode() && event.type == GdkEventType.BUTTON_PRESS && event.button == 3) {
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

        showPopupMenu(treeview, event);
        return 1;
    }
    return 0;
}

static int onSearchResultsPopupMenu(GtkTreeView *treeview, void* userdata) {
    showPopupMenu(treeview, null);
    return 1;
}