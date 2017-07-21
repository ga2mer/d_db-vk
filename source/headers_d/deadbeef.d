module deadbeefl;
/*
  deadbeef.h -- plugin API of the DeaDBeeF audio player
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
*/

import core.stdc.stdint;
import core.stdc.stdio;
import core.sys.posix.dirent;

extern (C):

// every plugin must define the following entry-point:
// extern "C" DB_plugin_t* $MODULENAME_load (DB_functions_t *api);
// where $MODULENAME is a name of module
// e.g. if your plugin is called "myplugin.so", $MODULENAME is "myplugin"
// this function should return pointer to DB_plugin_t structure
// that is enough for both static and dynamic modules

// backwards compatibility is supported since API version 1.0
// that means that the plugins which use the API 1.0 will work without recompiling until API 2.0.
//
// increments in the major version number mean that there are API breaks, and
// plugins must be recompiled to be compatible.
//
// add DDB_REQUIRE_API_VERSION(x,y) macro when you define the plugin structure
// like this:
// static DB_decoder_t plugin = {
//   DDB_REQUIRE_API_VERSION(1,0)
//  ............
// }
// this is required for versioning
// if you don't do it -- no version checking will be done (useful for debugging/development)
//
// please DON'T release plugins without version requirement
//
// to ensure compatibility, use the following before including deadbeef.h:
// #define DDB_API_LEVEL x
// where x is the minor API version number.
// that way, you'll get errors or warnings when using incompatible stuff.
//
// if you also want to get the deprecation warnings, use the following:
// #define DDB_WARN_DEPRECATED 1
//
// NOTE: deprecation doesn't mean the API is going to be removed, it just means
// that there's a better replacement in the newer deadbeef versions.

// api version history:
// 1.9 -- deadbeef-0.7.2
// 1.8 -- deadbeef-0.7.0
// 1.7 -- deadbeef-0.6.2
// 1.6 -- deadbeef-0.6.1
// 1.5 -- deadbeef-0.6
// 1.4 -- deadbeef-0.5.5
// 1.3 -- deadbeef-0.5.3
// 1.2 -- deadbeef-0.5.2
// 1.1 -- deadbeef-0.5.1
//   adds pass_through method to dsp plugins for optimization purposes
// 1.0 -- deadbeef-0.5.0
// 0.10 -- deadbeef-0.4.4-portable-r1 (note: 0.4.4 uses api v0.9)
// 0.9 -- deadbeef-0.4.3-portable-build3
// 0.8 -- deadbeef-0.4.2
// 0.7 -- deabdeef-0.4.0
// 0.6 -- deadbeef-0.3.3
// 0.5 -- deadbeef-0.3.2
// 0.4 -- deadbeef-0.3.0
// 0.3 -- deadbeef-0.2.3.2
// 0.2 -- deadbeef-0.2.3
// 0.1 -- deadbeef-0.2.0

enum DB_API_VERSION_MAJOR = 1;
enum DB_API_VERSION_MINOR = 9;

// avoid including glibc headers, this is not very portable
extern (D) auto __GNUC_PREREQ(T0, T1)(auto ref T0 maj, auto ref T1 min)
{
    return (__GNUC__ << 16) + __GNUC_MINOR__ >= (maj << 16) + min;
}

enum DDB_API_LEVEL = DB_API_VERSION_MINOR;

// backwards compat macro
//enum DB_PLUGIN_SET_API_VERSION = DDB_PLUGIN_SET_API_VERSION;

extern (D) auto PLUG_TEST_COMPAT(T0, T1, T2)(auto ref T0 plug, auto ref T1 x, auto ref T2 y)
{
    return plug.version_major == x && plug.version_minor >= y;
}

////////////////////////////
// default values for some common config variables should go here

// network.ctmapping : content-type to plugin mapping
enum DDB_DEFAULT_CTMAPPING = "audio/mpeg {stdmpg ffmpeg} audio/x-mpeg {stdmpg ffmpeg} application/ogg {stdogg ffmpeg} audio/ogg {stdogg ffmpeg} audio/aac {aac ffmpeg} audio/aacp {aac ffmpeg} audio/x-m4a {aac ffmpeg} audio/wma {wma ffmpeg}";

////////////////////////////
// playlist structures

// that's a good candidate for redesign
// short explanation: PL_MAIN and PL_SEARCH are used as "iter" argument in
// playlist functions, to reference main or search playlist, respectively
enum PL_MAIN = 0;
enum PL_SEARCH = 1;

enum
{
    DDB_IS_SUBTRACK = 1, // file is not single-track, might have metainfo in external file
    DDB_IS_READONLY = 2, // check this flag to block tag writing (e.g. in iso.wv)
    DDB_HAS_EMBEDDED_CUESHEET = 4,

    DDB_TAG_ID3V1 = 256,
    DDB_TAG_ID3V22 = 512,
    DDB_TAG_ID3V23 = 1024,
    DDB_TAG_ID3V24 = 2048,
    DDB_TAG_APEV2 = 4096,
    DDB_TAG_VORBISCOMMENTS = 8192,
    DDB_TAG_CUESHEET = 16384,
    DDB_TAG_ICY = 32768,
    DDB_TAG_ITUNES = 65536,

    DDB_TAG_MASK = 1048320
}

// playlist item
// these are "public" fields, available to plugins
struct DB_playItem_s
{
    int startsample; // start sample of track, or -1 for auto
    int endsample; // end sample of track, or -1 for auto
    int shufflerating; // sort order for shuffle mode
}

alias ddb_playItem_t = DB_playItem_s;

alias DB_playItem_t = DB_playItem_s;

struct ddb_playlist_t
{
}

struct DB_metaInfo_s
{
    DB_metaInfo_s* next;
    const(char)* key;
    const(char)* value;
}

alias DB_metaInfo_t = DB_metaInfo_s;

// FIXME: that needs to be in separate plugin

enum JUNK_STRIP_ID3V2 = 1;
enum JUNK_STRIP_APEV2 = 2;
enum JUNK_STRIP_ID3V1 = 4;
enum JUNK_WRITE_ID3V2 = 8;
enum JUNK_WRITE_APEV2 = 16;
enum JUNK_WRITE_ID3V1 = 32;

struct DB_id3v2_frame_s
{
    DB_id3v2_frame_s* next;
    char[5] id;
    uint size;
    ubyte[2] flags;
    ubyte[0] data;
}

alias DB_id3v2_frame_t = DB_id3v2_frame_s;

struct DB_id3v2_tag_s
{
    ubyte[2] version_;
    ubyte flags;
    DB_id3v2_frame_t* frames;
}

alias DB_id3v2_tag_t = DB_id3v2_tag_s;

struct DB_apev2_frame_s
{
    DB_apev2_frame_s* next;
    uint flags;
    char[256] key;
    uint size; // size of data
    ubyte[0] data;
}

alias DB_apev2_frame_t = DB_apev2_frame_s;

struct DB_apev2_tag_s
{
    uint version_;
    uint flags;
    DB_apev2_frame_t* frames;
}

alias DB_apev2_tag_t = DB_apev2_tag_s;

// plugin types
enum
{
    DB_PLUGIN_DECODER = 1,
    DB_PLUGIN_OUTPUT = 2,
    DB_PLUGIN_DSP = 3,
    DB_PLUGIN_MISC = 4,
    DB_PLUGIN_VFS = 5,
    DB_PLUGIN_PLAYLIST = 6,
    DB_PLUGIN_GUI = 7
}

// output plugin states
enum output_state_t
{
    OUTPUT_STATE_STOPPED = 0,
    OUTPUT_STATE_PLAYING = 1,
    OUTPUT_STATE_PAUSED = 2
}

// playback order
enum playback_order_t
{
    PLAYBACK_ORDER_LINEAR = 0,
    PLAYBACK_ORDER_SHUFFLE_TRACKS = 1,
    PLAYBACK_ORDER_RANDOM = 2,
    PLAYBACK_ORDER_SHUFFLE_ALBUMS = 3
}

// playback modes
enum playback_mode_t
{
    PLAYBACK_MODE_LOOP_ALL = 0, // loop playlist
    PLAYBACK_MODE_NOLOOP = 1, // don't loop
    PLAYBACK_MODE_LOOP_SINGLE = 2 // loop single track
}

// playlist change info, used in the DB_EV_PLAYLISTCHANGED p1 argument
enum ddb_playlist_change_t
{
    DDB_PLAYLIST_CHANGE_CONTENT = 0, // this is the most generic one, will work for the cases when p1 was omitted (0)
    DDB_PLAYLIST_CHANGE_CREATED = 1,
    DDB_PLAYLIST_CHANGE_DELETED = 2,
    DDB_PLAYLIST_CHANGE_POSITION = 3,
    DDB_PLAYLIST_CHANGE_TITLE = 4,
    DDB_PLAYLIST_CHANGE_SELECTION = 5,
    DDB_PLAYLIST_CHANGE_SEARCHRESULT = 6,
    DDB_PLAYLIST_CHANGE_PLAYQUEUE = 7
}

struct ddb_event_t
{
    int event;
    int size;
}

struct ddb_event_track_t
{
    ddb_event_t ev;
    DB_playItem_t* track;
    float playtime; // for SONGFINISHED event -- for how many seconds track was playing
    time_t started_timestamp; // time when "track" started playing
}

struct ddb_event_trackchange_t
{
    ddb_event_t ev;
    DB_playItem_t* from;
    DB_playItem_t* to;
    float playtime; // for SONGCHANGED event -- for how many seconds prev track was playing
    time_t started_timestamp; // time when "from" started playing
}

struct ddb_event_state_t
{
    ddb_event_t ev;
    int state;
}

struct ddb_event_playpos_t
{
    ddb_event_t ev;
    DB_playItem_t* track;
    float playpos;
}

struct DB_conf_item_s
{
    char* key;
    char* value;
    DB_conf_item_s* next;
}

alias DB_conf_item_t = DB_conf_item_s;

// event callback type
alias DB_callback_t = int function (ddb_event_t*, uintptr_t data);

// events
enum
{
    DB_EV_NEXT = 1, // switch to next track
    DB_EV_PREV = 2, // switch to prev track
    DB_EV_PLAY_CURRENT = 3, // play current track (will start/unpause if stopped or paused)
    DB_EV_PLAY_NUM = 4, // play track nr. p1
    DB_EV_STOP = 5, // stop current track
    DB_EV_PAUSE = 6, // pause playback
    DB_EV_PLAY_RANDOM = 7, // play random track
    DB_EV_TERMINATE = 8, // must be sent to player thread to terminate
    DB_EV_PLAYLIST_REFRESH = 9, // [DEPRECATED IN API LEVEL 8, use DB_EV_PLAYLISTCHANGED instead] save and redraw current playlist
    DB_EV_REINIT_SOUND = 10, // reinitialize sound output with current output_plugin config value
    DB_EV_CONFIGCHANGED = 11, // one or more config options were changed
    DB_EV_TOGGLE_PAUSE = 12,
    DB_EV_ACTIVATED = 13, // will be fired every time player is activated
    DB_EV_PAUSED = 14, // player was paused or unpaused

    DB_EV_PLAYLISTCHANGED = 15, // playlist contents were changed (e.g. metadata in any track)
    // DB_EV_PLAYLISTCHANGED NOTE: it's usually sent on LARGE changes,
    // when multiple tracks are affected, while for single tracks
    // the DB_EV_TRACKINFOCHANGED is preferred
    // added in API level 8:
    // p1 is one of ddb_playlist_change_t enum values, detailing what exactly has been changed.

    DB_EV_VOLUMECHANGED = 16, // volume was changed
    DB_EV_OUTPUTCHANGED = 17, // sound output plugin changed
    DB_EV_PLAYLISTSWITCHED = 18, // playlist switch occured
    DB_EV_SEEK = 19, // seek current track to position p1 (ms)
    DB_EV_ACTIONSCHANGED = 20, // plugin actions were changed, e.g. for reinitializing gui
    DB_EV_DSPCHAINCHANGED = 21, // emitted when any parameter of the main dsp chain has been changed

    // since 1.5

    DB_EV_SELCHANGED = 22, // selection changed in playlist p1 iter p2, ctx should be a pointer to playlist viewer instance, which caused the change, or NULL
    DB_EV_PLUGINSLOADED = 23, // after all plugins have been loaded and connected

    DB_EV_FOCUS_SELECTION = 24, // tell playlist viewer to focus on selection

    // -----------------
    // structured events

    DB_EV_FIRST = 1000,
    DB_EV_SONGCHANGED = 1000, // current song changed from one to another, ctx=ddb_event_trackchange_t
    DB_EV_SONGSTARTED = 1001, // song started playing, ctx=ddb_event_track_t
    DB_EV_SONGFINISHED = 1002, // song finished playing, ctx=ddb_event_track_t

    DB_EV_TRACKINFOCHANGED = 1004, // trackinfo was changed (included medatata, playback status, playqueue state, etc), ctx=ddb_event_track_t
    // DB_EV_TRACKINFOCHANGED NOTE: when multiple tracks change, DB_EV_PLAYLISTCHANGED may be sent instead,
    // for speed reasons, so always handle both events.

    DB_EV_SEEKED = 1005, // seek happened, ctx=ddb_event_playpos_t

    // since 1.5

    // NOTE: this is not a structured event, but too late to fix, needs to stay here for backwards compat
    DB_EV_TRACKFOCUSCURRENT = 1006, // user wants to highlight/find the current playing track

    DB_EV_MAX = 1007
}

// preset columns, working using IDs
// DON'T add new ids in range 2-7, they are reserved for backwards compatibility
enum pl_column_t
{
    DB_COLUMN_FILENUMBER = 0,
    DB_COLUMN_PLAYING = 1,
    DB_COLUMN_ALBUM_ART = 8
}

// replaygain constants
enum
{
    DDB_REPLAYGAIN_ALBUMGAIN = 0,
    DDB_REPLAYGAIN_ALBUMPEAK = 1,
    DDB_REPLAYGAIN_TRACKGAIN = 2,
    DDB_REPLAYGAIN_TRACKPEAK = 3
}

// sort order constants
enum ddb_sort_order_t
{
    DDB_SORT_DESCENDING = 0,
    DDB_SORT_ASCENDING = 1,
    // since 1.3

    DDB_SORT_RANDOM = 2
}

enum ddb_sys_directory_t
{
    DDB_SYS_DIR_CONFIG = 1,
    DDB_SYS_DIR_PREFIX = 2,
    DDB_SYS_DIR_DOC = 3,
    DDB_SYS_DIR_PLUGIN = 4,
    DDB_SYS_DIR_PIXMAP = 5,
    DDB_SYS_DIR_CACHE = 6
}

// typecasting macros
extern (D) auto DB_PLUGIN(T)(auto ref T x)
{
    return cast(DB_plugin_t*) x;
}

extern (D) auto DB_CALLBACK(T)(auto ref T x)
{
    return cast(DB_callback_t) x;
}

extern (D) auto DB_EVENT(T)(auto ref T x)
{
    return cast(ddb_event_t*) x;
}

extern (D) auto DB_PLAYITEM(T)(auto ref T x)
{
    return cast(DB_playItem_t*) x;
}

// FILE object wrapper for vfs access
struct DB_FILE
{
    DB_vfs_s* vfs;
}

// md5 calc control structure (see md5/md5.h)
struct DB_md5_s
{
    char[88] data;
}

alias DB_md5_t = DB_md5_s;

struct ddb_waveformat_t
{
    int bps;
    int channels;
    int samplerate;
    uint channelmask;
    int is_float; // bps must be 32 if this is true
    int is_bigendian;
}

// since 1.5
enum DDB_FREQ_BANDS = 256;
enum DDB_FREQ_MAX_CHANNELS = 9;

struct ddb_audio_data_s
{
    const(ddb_waveformat_t)* fmt;
    const(float)* data;
    int nframes;
}

alias ddb_audio_data_t = ddb_audio_data_s;

struct ddb_fileadd_data_s
{
    int visibility;
    ddb_playlist_t* plt;
    ddb_playItem_t* track;
}

alias ddb_fileadd_data_t = ddb_fileadd_data_s;

// since 1.8
enum
{
    DDB_TF_CONTEXT_HAS_INDEX = 1,
    DDB_TF_CONTEXT_HAS_ID = 2,
    DDB_TF_CONTEXT_NO_DYNAMIC = 4, // skip dynamic fields (%playback_time%)

    // Don't convert linebreaks to semicolons
    DDB_TF_CONTEXT_MULTILINE = 8
}

// context for title formatting interpreter
struct ddb_tf_context_t
{
    int _size; // must be set to sizeof(tf_context_t)
    uint flags; // DDB_TF_CONTEXT_ flags
    ddb_playItem_t* it; // track to get information from, or NULL
    ddb_playlist_t* plt; // playlist in which the track resides, or NULL

    // NOTE: when plt is NULL, it means that the track is not in any playlist,
    // that is -- playlist will never be automatically guessed, for performance
    // reasons.

    // index of the track in playlist the track belongs to
    // if present, DDB_TF_CONTEXT_HAS_INDEX flag must be set
    int idx;

    // predefined column id, one of the DB_COLUMN_
    // if present, DDB_TF_CONTEXT_HAS_ID flag must be set
    int id;

    int iter; // playlist iteration (PL_MAIN, PL_SEARCH)

    // update is a returned value
    // meaning:
    // 0: no automatic updates
    // <0: updates on every call
    // >0: number of milliseconds between updates / until next update
    int update;
}

// forward decl for plugin struct

// player api definition
struct DB_functions_t
{
    // versioning
    int vmajor;
    int vminor;

    // md5sum calc
    void function (ubyte[16] sig, const(char)* in_, int len) md5;
    void function (char* str, const(ubyte)[16] sig) md5_to_str;
    void function (DB_md5_t* s) md5_init;
    void function (DB_md5_t* s, const(ubyte)* data, int nbytes) md5_append;
    void function (DB_md5_t* s, ubyte[16] digest) md5_finish;

    // playback control
    DB_output_s* function () get_output;
    float function () playback_get_pos; // [0..100]
    void function (float pos) playback_set_pos; // [0..100]

    // streamer access
    DB_playItem_t* function () streamer_get_playing_track;
    DB_playItem_t* function () streamer_get_streaming_track;
    float function () streamer_get_playpos;
    int function (int len) streamer_ok_to_read;
    void function (int full) streamer_reset;
    int function (char* bytes, int size) streamer_read;
    void function (int bitrate) streamer_set_bitrate;
    int function () streamer_get_apx_bitrate;
    DB_fileinfo_s* function () streamer_get_current_fileinfo;
    int function () streamer_get_current_playlist;
    ddb_dsp_context_s* function () streamer_get_dsp_chain;
    void function (ddb_dsp_context_s* chain) streamer_set_dsp_chain;
    void function () streamer_dsp_refresh; // call after changing parameters

    // system folders
    // normally functions will return standard folders derived from --prefix
    // portable version will return pathes specified in comments below
    const(char)* function () get_config_dir; // installdir/config | $XDG_CONFIG_HOME/.config/deadbeef
    const(char)* function () get_prefix; // installdir | PREFIX
    const(char)* function () get_doc_dir; // installdir/doc | DOCDIR
    const(char)* function () get_plugin_dir; // installdir/plugins | LIBDIR/deadbeef
    const(char)* function () get_pixmap_dir; // installdir/pixmaps | PREFIX "/share/deadbeef/pixmaps"

    // process control
    void function () quit;

    // threading
    intptr_t function (void function (void* ctx) fn, void* ctx) thread_start;
    intptr_t function (void function (void* ctx) fn, void* ctx) thread_start_low_priority;
    int function (intptr_t tid) thread_join;
    int function (intptr_t tid) thread_detach;
    void function (void* retval) thread_exit;
    uintptr_t function () mutex_create;
    uintptr_t function () mutex_create_nonrecursive;
    void function (uintptr_t mtx) mutex_free;
    int function (uintptr_t mtx) mutex_lock;
    int function (uintptr_t mtx) mutex_unlock;
    uintptr_t function () cond_create;
    void function (uintptr_t cond) cond_free;
    int function (uintptr_t cond, uintptr_t mutex) cond_wait;
    int function (uintptr_t cond) cond_signal;
    int function (uintptr_t cond) cond_broadcast;

    /////// playlist management //////
    void function (ddb_playlist_t* plt) plt_ref;
    void function (ddb_playlist_t* plt) plt_unref;

    // total number of playlists
    int function () plt_get_count;

    // 1st item in playlist nr. 'plt'
    DB_playItem_t* function (int plt) plt_get_head;

    // nr. of selected items in playlist nr. 'plt'
    int function (int plt) plt_get_sel_count;

    // add new playlist into position before nr. 'before', with title='title'
    // returns index of new playlist
    int function (int before, const(char)* title) plt_add;

    // remove playlist nr. plt
    void function (int plt) plt_remove;

    // clear playlist
    void function (ddb_playlist_t* plt) plt_clear;
    void function () pl_clear;

    // set current playlist
    void function (ddb_playlist_t* plt) plt_set_curr;
    void function (int plt) plt_set_curr_idx;

    // get current playlist
    // note: caller is responsible to call plt_unref after using pointer
    // returned by plt_get_curr
    ddb_playlist_t* function () plt_get_curr;
    int function () plt_get_curr_idx;

    // move playlist nr. 'from' into position before nr. 'before', where
    // before=-1 means last position
    void function (int from, int before) plt_move;

    // playlist saving and loading
    DB_playItem_t* function (ddb_playlist_t* plt, DB_playItem_t* after, const(char)* fname, int* pabort, int function (DB_playItem_t* it, void* data) cb, void* user_data) plt_load;
    int function (ddb_playlist_t* plt, DB_playItem_t* first, DB_playItem_t* last, const(char)* fname, int* pabort, int function (DB_playItem_t* it, void* data) cb, void* user_data) plt_save;

    ddb_playlist_t* function (int idx) plt_get_for_idx;
    int function (ddb_playlist_t* plt, char* buffer, int bufsize) plt_get_title;
    int function (ddb_playlist_t* plt, const(char)* title) plt_set_title;

    // increments modification index
    void function (ddb_playlist_t* handle) plt_modified;

    // returns modication index
    // the index is incremented by 1 every time playlist changes
    int function (ddb_playlist_t* handle) plt_get_modification_idx;

    // return index of an item in specified playlist, or -1 if not found
    int function (ddb_playlist_t* plt, DB_playItem_t* it, int iter) plt_get_item_idx;

    // playlist metadata
    // this kind of metadata is stored in playlist (dbpl) files
    // that is, this is the properties of playlist itself,
    // not of the tracks in the playlist.
    // for example, playlist tab color can be stored there, etc

    // add meta if it doesn't exist yet
    void function (ddb_playlist_t* handle, const(char)* key, const(char)* value) plt_add_meta;

    // replace (or add) existing meta
    void function (ddb_playlist_t* handle, const(char)* key, const(char)* value) plt_replace_meta;

    // append meta to existing one, or add if doesn't exist
    void function (ddb_playlist_t* handle, const(char)* key, const(char)* value) plt_append_meta;

    // set integer meta (works same as replace)
    void function (ddb_playlist_t* handle, const(char)* key, int value) plt_set_meta_int;

    // set float meta (works same as replace)
    void function (ddb_playlist_t* handle, const(char)* key, float value) plt_set_meta_float;

    // plt_find_meta must always be used in the pl_lock/unlock block
    const(char)* function (ddb_playlist_t* handle, const(char)* key) plt_find_meta;

    // returns head of metadata linked list, for direct access
    // remember pl_lock/unlock
    DB_metaInfo_t* function (ddb_playlist_t* handle) plt_get_metadata_head;

    // delete meta item from list
    void function (ddb_playlist_t* handle, DB_metaInfo_t* meta) plt_delete_metadata;

    // returns integer value of requested meta, def is the default value if not found
    int function (ddb_playlist_t* handle, const(char)* key, int def) plt_find_meta_int;

    // returns float value of requested meta, def is the default value if not found
    float function (ddb_playlist_t* handle, const(char)* key, float def) plt_find_meta_float;

    // delete all metadata
    void function (ddb_playlist_t* handle) plt_delete_all_meta;

    // operating on playlist items
    DB_playItem_t* function (ddb_playlist_t* playlist, DB_playItem_t* after, DB_playItem_t* it) plt_insert_item;
    DB_playItem_t* function (ddb_playlist_t* playlist, DB_playItem_t* after, const(char)* fname, int* pabort, int function (DB_playItem_t* it, void* data) cb, void* user_data) plt_insert_file;
    DB_playItem_t* function (ddb_playlist_t* plt, DB_playItem_t* after, const(char)* dirname, int* pabort, int function (DB_playItem_t* it, void* data) cb, void* user_data) plt_insert_dir;
    void function (ddb_playlist_t* plt, DB_playItem_t* it, float duration) plt_set_item_duration;
    int function (ddb_playlist_t* playlist, DB_playItem_t* it) plt_remove_item;
    int function (ddb_playlist_t* playlist) plt_getselcount;
    float function (ddb_playlist_t* plt) plt_get_totaltime;
    int function (ddb_playlist_t* plt, int iter) plt_get_item_count;
    int function (ddb_playlist_t* plt) plt_delete_selected;
    void function (ddb_playlist_t* plt, int iter, int cursor) plt_set_cursor;
    int function (ddb_playlist_t* plt, int iter) plt_get_cursor;
    void function (ddb_playlist_t* plt) plt_select_all;
    void function (ddb_playlist_t* plt) plt_crop_selected;
    DB_playItem_t* function (ddb_playlist_t* plt, int iter) plt_get_first;
    DB_playItem_t* function (ddb_playlist_t* plt, int iter) plt_get_last;
    DB_playItem_t* function (ddb_playlist_t* playlist, int idx, int iter) plt_get_item_for_idx;
    void function (ddb_playlist_t* to, int iter, ddb_playlist_t* from, DB_playItem_t* drop_before, uint* indexes, int count) plt_move_items;
    void function (ddb_playlist_t* to, int iter, ddb_playlist_t* from, DB_playItem_t* before, uint* indices, int cnt) plt_copy_items;
    void function (ddb_playlist_t* plt) plt_search_reset;
    void function (ddb_playlist_t* plt, const(char)* text) plt_search_process;

    // sort using the title formatting v1 (deprecated)
    void function (ddb_playlist_t* plt, int iter, int id, const(char)* format, int order) plt_sort;

    // add files and folders to current playlist
    int function (ddb_playlist_t* plt, const(char)* fname, int function (DB_playItem_t* it, void* data) cb, void* user_data) plt_add_file;
    int function (ddb_playlist_t* plt, const(char)* dirname, int function (DB_playItem_t* it, void* data) cb, void* user_data) plt_add_dir;

    // cuesheet support
    DB_playItem_t* function (ddb_playlist_t* plt, DB_playItem_t* after, DB_playItem_t* origin, const(ubyte)* buffer, int buffersize, int numsamples, int samplerate) plt_insert_cue_from_buffer;
    DB_playItem_t* function (ddb_playlist_t* plt, DB_playItem_t* after, DB_playItem_t* origin, int numsamples, int samplerate) plt_insert_cue;

    // playlist locking
    void function () pl_lock;
    void function () pl_unlock;

    // playlist tracks access
    DB_playItem_t* function () pl_item_alloc;
    DB_playItem_t* function (const(char)* fname, const(char)* decoder_id) pl_item_alloc_init;
    void function (DB_playItem_t* it) pl_item_ref;
    void function (DB_playItem_t* it) pl_item_unref;
    void function (DB_playItem_t* out_, DB_playItem_t* in_) pl_item_copy;

    // request lock for adding files to playlist
    // this function may return -1 if it is not possible to add files right now.
    // caller must cancel operation in this case,
    // or wait until previous operation finishes
    int function (ddb_playlist_t* plt) pl_add_files_begin;

    // release the lock for adding files to playlist
    // end must be called when add files operation is finished
    void function () pl_add_files_end;

    // most of this functions are self explanatory
    // if you don't get what they do -- look in the code

    // --- the following functions work with current playlist ---

    // get index of the track in MAIN
    int function (DB_playItem_t* it) pl_get_idx_of;

    // get index of the track in MAIN or SEARCH
    int function (DB_playItem_t* it, int iter) pl_get_idx_of_iter;

    // get track for index in MAIN
    DB_playItem_t* function (int idx) pl_get_for_idx;

    // get track for index in MAIN or SEARCH
    DB_playItem_t* function (int idx, int iter) pl_get_for_idx_and_iter;

    // get total play time of all tracks in MAIN
    float function () pl_get_totaltime;

    // get number of tracks in MAIN or SEARCH
    int function (int iter) pl_getcount;

    // delete selected tracks
    int function () pl_delete_selected;

    // set cursor position in MAIN or SEARCH
    void function (int iter, int cursor) pl_set_cursor;

    // get cursor position in MAIN
    int function (int iter) pl_get_cursor;

    // remove all except selected tracks
    void function () pl_crop_selected;

    // get number of selected tracks
    int function () pl_getselcount;

    // get first track in MAIN or SEARCH
    DB_playItem_t* function (int iter) pl_get_first;

    // get last track in MAIN or SEARCH
    DB_playItem_t* function (int iter) pl_get_last;

    // --- misc functions ---

    // mark the track as selected or unselected (1 or 0 respectively)
    void function (DB_playItem_t* it, int sel) pl_set_selected;

    // test whether the track is selected
    int function (DB_playItem_t* it) pl_is_selected;

    // save current playlist
    int function () pl_save_current;

    // save all playlists
    int function () pl_save_all;

    // select all tracks in current playlist
    void function () pl_select_all;

    // get next track
    DB_playItem_t* function (DB_playItem_t* it, int iter) pl_get_next;

    // get previous track
    DB_playItem_t* function (DB_playItem_t* it, int iter) pl_get_prev;

    /*
       pl_format_title formats the line for display in playlist
       @it pointer to playlist item
       @idx number of that item in playlist (or -1)
       @s output buffer
       @size size of output buffer
       @id one of IDs defined in pl_column_id_t enum, can be -1
       @fmt format string, used if id is -1
       format is printf-alike. specification:
       %a artist
       %t title
       %b album
       %B band / album artist
       %n track
       %l length (duration)
       %y year
       %g genre
       %c comment
       %r copyright
       %T tags
       %f filename without path
       %F full pathname/uri
       %d directory without path (e.g. /home/user/file.mp3 -> user)
       %D directory name with full path (e.g. /home/user/file.mp3 -> /home/user)
       more to come
    */
    int function (DB_playItem_t* it, int idx, char* s, int size, int id, const(char)* fmt) pl_format_title;

    // _escaped version wraps all conversions with '' and replaces every ' in conversions with \'
    int function (DB_playItem_t* it, int idx, char* s, int size, int id, const(char)* fmt) pl_format_title_escaped;

    // format duration 't' (fractional seconds) into string, for display in playlist
    void function (float t, char* dur, int size) pl_format_time;

    // find which playlist the specified item belongs to, returns NULL if none
    ddb_playlist_t* function (DB_playItem_t* it) pl_get_playlist;

    // direct access to metadata structures
    // not thread-safe, make sure to wrap with pl_lock/pl_unlock
    DB_metaInfo_t* function (DB_playItem_t* it) pl_get_metadata_head; // returns head of metadata linked list
    void function (DB_playItem_t* it, DB_metaInfo_t* meta) pl_delete_metadata;

    // high-level access to metadata
    void function (DB_playItem_t* it, const(char)* key, const(char)* value) pl_add_meta;
    void function (DB_playItem_t* it, const(char)* key, const(char)* value) pl_append_meta;
    void function (DB_playItem_t* it, const(char)* key, int value) pl_set_meta_int;
    void function (DB_playItem_t* it, const(char)* key, float value) pl_set_meta_float;
    void function (DB_playItem_t* it, const(char)* key) pl_delete_meta;

    // this function is not thread-safe
    // make sure to wrap it with pl_lock/pl_unlock block
    const(char)* function (DB_playItem_t* it, const(char)* key) pl_find_meta;

    // following functions are thread-safe
    int function (DB_playItem_t* it, const(char)* key, int def) pl_find_meta_int;
    float function (DB_playItem_t* it, const(char)* key, float def) pl_find_meta_float;
    void function (DB_playItem_t* it, const(char)* key, const(char)* value) pl_replace_meta;
    void function (DB_playItem_t* it) pl_delete_all_meta;
    float function (DB_playItem_t* it) pl_get_item_duration;
    uint function (DB_playItem_t* it) pl_get_item_flags;
    void function (DB_playItem_t* it, uint flags) pl_set_item_flags;
    void function (DB_playItem_t* from, DB_playItem_t* first, DB_playItem_t* last) pl_items_copy_junk;
    // idx is one of DDB_REPLAYGAIN_* constants
    void function (DB_playItem_t* it, int idx, float value) pl_set_item_replaygain;
    float function (DB_playItem_t* it, int idx) pl_get_item_replaygain;

    // playqueue support (obsolete since API 1.8)
    int function (DB_playItem_t* it) pl_playqueue_push;
    void function () pl_playqueue_clear;
    void function () pl_playqueue_pop;
    void function (DB_playItem_t* it) pl_playqueue_remove;
    int function (DB_playItem_t* it) pl_playqueue_test;

    // volume control
    void function (float dB) volume_set_db;
    float function () volume_get_db;
    void function (float amp) volume_set_amp;
    float function () volume_get_amp;
    float function () volume_get_min_db;

    // junk reading/writing
    int function (DB_playItem_t* it, DB_FILE* fp) junk_id3v1_read;
    int function (DB_FILE* fp) junk_id3v1_find;
    int function (FILE* fp, DB_playItem_t* it, const(char)* enc) junk_id3v1_write;
    int function (DB_FILE* fp, int* psize) junk_id3v2_find;
    int function (DB_playItem_t* it, DB_FILE* fp) junk_id3v2_read;
    int function (DB_playItem_t* it, DB_id3v2_tag_t* tag, DB_FILE* fp) junk_id3v2_read_full;
    int function (DB_id3v2_tag_t* tag24, DB_id3v2_tag_t* tag23) junk_id3v2_convert_24_to_23;
    int function (DB_id3v2_tag_t* tag23, DB_id3v2_tag_t* tag24) junk_id3v2_convert_23_to_24;
    int function (DB_id3v2_tag_t* tag22, DB_id3v2_tag_t* tag24) junk_id3v2_convert_22_to_24;
    void function (DB_id3v2_tag_t* tag) junk_id3v2_free;
    int function (FILE* file, DB_id3v2_tag_t* tag) junk_id3v2_write;
    DB_id3v2_frame_t* function (DB_id3v2_tag_t* tag, const(char)* frame_id, const(char)* value) junk_id3v2_add_text_frame;
    int function (DB_id3v2_tag_t* tag, const(char)* frame_id) junk_id3v2_remove_frames;
    int function (DB_playItem_t* it, DB_FILE* fp) junk_apev2_read;
    int function (DB_playItem_t* it, char* mem, int size) junk_apev2_read_mem;
    int function (DB_playItem_t* it, DB_apev2_tag_t* tag_store, DB_FILE* fp) junk_apev2_read_full;
    int function (DB_playItem_t* it, DB_apev2_tag_t* tag_store, char* mem, int memsize) junk_apev2_read_full_mem;
    int function (DB_FILE* fp, int* psize, uint* pflags, uint* pnumitems) junk_apev2_find;
    int function (DB_apev2_tag_t* tag, const(char)* frame_id) junk_apev2_remove_frames;
    DB_apev2_frame_t* function (DB_apev2_tag_t* tag, const(char)* frame_id, const(char)* value) junk_apev2_add_text_frame;
    void function (DB_apev2_tag_t* tag) junk_apev2_free;
    int function (FILE* fp, DB_apev2_tag_t* tag, int write_header, int write_footer) junk_apev2_write;
    int function (DB_FILE* fp) junk_get_leading_size;
    int function (FILE* fp) junk_get_leading_size_stdio;
    void function (DB_playItem_t* from, DB_playItem_t* first, DB_playItem_t* last) junk_copy;
    const(char)* function (const(char)* s) junk_detect_charset;
    int function (const(char)* in_, int inlen, char* out_, int outlen, const(char)* cs) junk_recode;
    int function (const(char)* in_, int inlen, char* out_, int outlen, const(char)* cs_in, const(char)* cs_out) junk_iconv;
    int function (DB_playItem_t* it, uint flags, int id3v2_version, const(char)* id3v1_encoding) junk_rewrite_tags;

    // vfs
    DB_FILE* function (const(char)* fname) fopen;
    void function (DB_FILE* f) fclose;
    size_t function (void* ptr, size_t size, size_t nmemb, DB_FILE* stream) fread;
    int function (DB_FILE* stream, long offset, int whence) fseek;
    long function (DB_FILE* stream) ftell;
    void function (DB_FILE* stream) rewind;
    long function (DB_FILE* stream) fgetlength;
    const(char)* function (DB_FILE* stream) fget_content_type;
    void function (DB_FILE* stream, DB_playItem_t* it) fset_track;
    void function (DB_FILE* stream) fabort;

    // message passing
    int function (uint id, uintptr_t ctx, uint p1, uint p2) sendmessage;

    // convenience functions to send events, uses sendmessage internally
    ddb_event_t* function (uint id) event_alloc;
    void function (ddb_event_t* ev) event_free;
    int function (ddb_event_t* ev, uint p1, uint p2) event_send;

    // configuration access
    //
    // conf_get_str_fast is not thread-safe, and
    // must only be used from within conf_lock/conf_unlock block
    // it should be preferred for fast non-blocking lookups
    //
    // all the other config access functions are thread safe
    void function () conf_lock;
    void function () conf_unlock;
    const(char)* function (const(char)* key, const(char)* def) conf_get_str_fast;
    void function (const(char)* key, const(char)* def, char* buffer, int buffer_size) conf_get_str;
    float function (const(char)* key, float def) conf_get_float;
    int function (const(char)* key, int def) conf_get_int;
    long function (const(char)* key, long def) conf_get_int64;
    void function (const(char)* key, const(char)* val) conf_set_str;
    void function (const(char)* key, int val) conf_set_int;
    void function (const(char)* key, long val) conf_set_int64;
    void function (const(char)* key, float val) conf_set_float;
    DB_conf_item_t* function (const(char)* group, DB_conf_item_t* prev) conf_find;
    void function (const(char)* key) conf_remove_items;
    int function () conf_save;

    // plugin communication
    DB_decoder_s** function () plug_get_decoder_list;
    DB_vfs_s** function () plug_get_vfs_list;
    DB_output_s** function () plug_get_output_list;
    DB_dsp_s** function () plug_get_dsp_list;
    DB_playlist_s** function () plug_get_playlist_list;
    DB_plugin_s** function () plug_get_list;
    const(char*)* function () plug_get_gui_names;
    const(char)* function (const(char)* id) plug_get_decoder_id;
    void function (const(char)* id) plug_remove_decoder_id;
    DB_plugin_s* function (const(char)* id) plug_get_for_id;

    // misc utilities
    // returns 1 if the track is represented as a local file
    // returns 0 if it's a remote file, e.g. a network stream
    // since API 1.5 it also returns 1 for vfs tracks, e.g. from ZIP files
    int function (const(char)* fname) is_local_file;

    // pcm utilities
    int function (const(ddb_waveformat_t)* inputfmt, const(char)* input, const(ddb_waveformat_t)* outputfmt, char* output, int inputsize) pcm_convert;

    // dsp preset management
    int function (const(char)* fname, ddb_dsp_context_s** head) dsp_preset_load;
    int function (const(char)* fname, ddb_dsp_context_s* head) dsp_preset_save;
    void function (ddb_dsp_context_s* head) dsp_preset_free;

    // since 1.2

    ddb_playlist_t* function (const(char)* title) plt_alloc;
    void function (ddb_playlist_t* plt) plt_free;

    void function (ddb_playlist_t* plt, int fast) plt_set_fast_mode;
    int function (ddb_playlist_t* plt) plt_is_fast_mode;

    const(char)* function (const(char)* str) metacache_add_string;
    void function (const(char)* str) metacache_remove_string;
    void function (const(char)* str) metacache_ref;
    void function (const(char)* str) metacache_unref;

    // this function must return original un-overriden value (ignoring the keys prefixed with '!')
    // it's not thread-safe, and must be used under the same conditions as the
    // pl_find_meta
    const(char)* function (DB_playItem_t* it, const(char)* key) pl_find_meta_raw;

    // since 1.3

    int function () streamer_dsp_chain_save;

    // since 1.4

    int function (DB_playItem_t* it, const(char)* key, char* val, int size) pl_get_meta;
    int function (DB_playItem_t* it, const(char)* key, char* val, int size) pl_get_meta_raw;
    int function (ddb_playlist_t* handle, const(char)* key, char* val, int size) plt_get_meta;

    // fast way to test if a field exists in playitem
    int function (DB_playItem_t* it, const(char)* key) pl_meta_exists;

    // since 1.5

    // register/unregister for getting continuous wave data
    // mainly for visualization
    // ctx must be unique
    // the waveform data can be arbitrary size
    // the samples are interleaved
    void function (void* ctx, void function (void* ctx, ddb_audio_data_t* data) callback) vis_waveform_listen;
    void function (void* ctx) vis_waveform_unlisten;

    // register/unregister for getting continuous spectrum (frequency domain) data
    // mainly for visualization
    // ctx must be unique
    // the data always contains DDB_FREQ_BANDS frames
    // max number of channels is DDB_FREQ_MAX_CHANNELS
    // the samples are non-interleaved
    void function (void* ctx, void function (void* ctx, ddb_audio_data_t* data) callback) vis_spectrum_listen;
    void function (void* ctx) vis_spectrum_unlisten;

    // this is useful to mute/unmute audio, and query the muted status, from
    // plugins, without touching the volume control
    void function (int mute) audio_set_mute;
    int function () audio_is_mute;

    // this is useful for prompting a user when he attempts to quit the player
    // while something is working in background, e.g. the Converter,
    // and let him finish or cancel the background jobs.
    void function () background_job_increment;
    void function () background_job_decrement;
    int function () have_background_jobs;

    // utility function to get plt idx from handle
    int function (ddb_playlist_t* plt) plt_get_idx;

    // save referenced playlist in config
    // same as pl_save_current, but for index
    int function (int n) plt_save_n;

    // same as pl_save_current, but for playlist pointer
    int function (ddb_playlist_t* plt) plt_save_config;

    // register file added callback
    // the callback will be called for each file
    // the visibility is taken from plt_add_* arguments
    // the callback must return 0 to continue, or -1 to abort the operation.
    // returns ID
    int function (int function (ddb_fileadd_data_t* data, void* user_data) callback, void* user_data) listen_file_added;
    void function (int id) unlisten_file_added;

    int function (void function (ddb_fileadd_data_t* data, void* user_data) callback_begin, void function (ddb_fileadd_data_t* data, void* user_data) callback_end, void* user_data) listen_file_add_beginend;
    void function (int id) unlisten_file_add_beginend;

    // visibility is a number, which tells listeners about the caller.
    // the value DDB_FILEADD_VISIBILITY_GUI (or 0) is reserved for callers which
    // want the GUI to intercept the calls and show visual updates.
    //
    // this is the default value passed from plt_load, plt_add_dir, plt_add_file.
    //
    // the values up to 10 are registered for deadbeef itself, so please avoid
    // using them in your plugins, unless you really know what you're doing.
    // any values above 10 are free for any use.
    //
    // the "callback", if not NULL, will be called with the passed "user_data",
    // for each track.
    //
    // the registered listeners will be called too, the ddb_fileadd_data_t
    // has the visibility
    DB_playItem_t* function (int visibility, ddb_playlist_t* plt, ddb_playItem_t* after, const(char)* fname, int* pabort, int function (DB_playItem_t* it, void* user_data) callback, void* user_data) plt_load2;
    int function (int visibility, ddb_playlist_t* plt, const(char)* fname, int function (DB_playItem_t* it, void* user_data) callback, void* user_data) plt_add_file2;
    int function (int visibility, ddb_playlist_t* plt, const(char)* dirname, int function (DB_playItem_t* it, void* user_data) callback, void* user_data) plt_add_dir2;
    ddb_playItem_t* function (int visibility, ddb_playlist_t* playlist, ddb_playItem_t* after, const(char)* fname, int* pabort, int function (DB_playItem_t* it, void* user_data) callback, void* user_data) plt_insert_file2;
    ddb_playItem_t* function (int visibility, ddb_playlist_t* plt, ddb_playItem_t* after, const(char)* dirname, int* pabort, int function (DB_playItem_t* it, void* user_data) callback, void* user_data) plt_insert_dir2;

    // request lock for adding files to playlist
    // returns 0 on success
    // this function may return -1 if it is not possible to add files right now.
    // caller must cancel operation in this case,
    // or wait until previous operation finishes
    // NOTE: it's not guaranteed that all deadbeef versions support
    // adding the files to different playlists in parallel.
    int function (ddb_playlist_t* plt, int visibility) plt_add_files_begin;

    // release the lock for adding files to playlist
    // end must be called when add files operation is finished
    void function (ddb_playlist_t* plt, int visibility) plt_add_files_end;

    // deselect all tracks in playlist
    void function (ddb_playlist_t* plt) plt_deselect_all;

    // since 1.6

    void function (ddb_playlist_t* plt, int scroll) plt_set_scroll;
    int function (ddb_playlist_t* plt) plt_get_scroll;

    // since 1.8

    // **** title formatting v2 ****

    // compile the input title formatting string into bytecode
    // script: freeform string with title formatting special characters in it
    // returns the pointer to compiled bytecode, which must be tf_free'd by the caller.
    char* function (const(char)* script) tf_compile;

    // free the code returned by tf_compile
    void function (char* code) tf_free;

    // evaluate the titleformatting script in a given context
    // ctx: a pointer to ddb_tf_context_t structure initialized by the caller
    // code: the bytecode data created by tf_compile
    // out: buffer allocated by the caller, must be big enough to fit the output string
    // outlen: the size of out buffer
    // returns -1 on fail, output size on success
    int function (ddb_tf_context_t* ctx, const(char)* code, char* out_, int outlen) tf_eval;

    // sort using title formatting v2
    void function (ddb_playlist_t* plt, int iter, int id, const(char)* format, int order) plt_sort_v2;

    // playqueue APIs
    int function (DB_playItem_t* it) playqueue_push;
    void function () playqueue_pop;
    void function (DB_playItem_t* it) playqueue_remove;
    void function () playqueue_clear;
    int function (DB_playItem_t* it) playqueue_test;
    int function () playqueue_get_count;
    DB_playItem_t* function (int n) playqueue_get_item;
    int function (int n) playqueue_remove_nth;
    void function (int n, DB_playItem_t* it) playqueue_insert_at;

    // system directory API, returns path by id from ddb_sys_directory_t enum
    const(char)* function (int dir_id) get_system_dir;

    // set the selected playlist for the ongoing plugin action.
    // the "set" function is expected to be called by the UI plugin,
    // while the "get" is expected to be called by the action code.
    void function (ddb_playlist_t* plt) action_set_playlist;

    // returns one of:
    // selected playlist for context menu for the DDB_ACTION_CTX_PLAYLIST,
    // or the current active playlist for any other context.
    // returned value cannot be NULL
    // returned value is refcounted, so remember to call plt_unref.
    ddb_playlist_t* function () action_get_playlist;

    // convert legacy title formatting to the new format, usable with tf_compile
    void function (const(char)* fmt, char* out_, int outsize) tf_import_legacy;
}

// NOTE: an item placement must be selected like this
// if (flags & DB_ACTION_COMMON)  -> main menu, or nowhere, or where GUI plugin wants
//    basically, to put it into main menu, prefix the item title with the menu name
//    e.g. title = "File/MyItem" --> this will add the item under File menu
//
// if (flags & PLAYLIST)  -> playlist (tab) context menu
//
// if (none of the above)  -> track context menu

enum
{
    /* Action in main menu (or whereever ui prefers) */
    DB_ACTION_COMMON = 1,

    /* Can handle single track */
    DB_ACTION_SINGLE_TRACK = 2,

    /* Can handle multiple tracks */
    DB_ACTION_MULTIPLE_TRACKS = 4,

    /* DEPRECATED in API 1.5 */
    DB_ACTION_ALLOW_MULTIPLE_TRACKS = 4,

    /* DEPRECATED in API 1.5, ignored in callback2 */
    /* Action can (and prefer) traverse multiple tracks by itself */
    DB_ACTION_CAN_MULTIPLE_TRACKS = 8,

    /* Action is inactive */
    DB_ACTION_DISABLED = 16,

    /* DEPRECATED in API 1.5, ignored in callback2 */
    /* since 1.2 */
    /* Action for the playlist (tab) */
    DB_ACTION_PLAYLIST = 32,

    /* add item to menu(s), if contains slash symbol(s) */
    DB_ACTION_ADD_MENU = 64
}

// action contexts
// since 1.5
enum
{
    DDB_ACTION_CTX_MAIN = 0,
    DDB_ACTION_CTX_SELECTION = 1,
    // NOTE: starting with API 1.8, plugins should be using the
    // action_get_playlist function for getting the playlist pointer.
    DDB_ACTION_CTX_PLAYLIST = 2,
    DDB_ACTION_CTX_NOWPLAYING = 3,
    DDB_ACTION_CTX_COUNT = 4
}

alias DB_plugin_action_callback_t = int function (DB_plugin_action_s* action, void* userdata);
alias DB_plugin_action_callback2_t = int function (DB_plugin_action_s* action, int ctx);

struct DB_plugin_action_s
{
    const(char)* title;
    const(char)* name;
    uint flags;
    // the use of "callback" is deprecated,
    // only use it if the code must be compatible with API 1.4
    // otherwise switch to callback2
    DB_plugin_action_callback_t callback;
    DB_plugin_action_s* next;

    DB_plugin_action_callback2_t callback2;
}

alias DB_plugin_action_t = DB_plugin_action_s;

// base plugin interface
struct DB_plugin_s
{
    // type must be one of DB_PLUGIN_ types
    int type;
    // api version
    short api_vmajor;
    short api_vminor;
    // plugin version
    short version_major;
    short version_minor;

    uint flags; // currently unused
    uint reserved1;
    uint reserved2;
    uint reserved3;

    // any of those can be left NULL
    // though it's much better to fill them with something useful
    const(char)* id; // id used for serialization and runtime binding
    const(char)* name; // short name
    const(char)* descr; // short description (what the plugin is doing)
    const(char)* copyright; // copyright notice(s), list of developers, links to original works, etc
    const(char)* website; // plugin website

    // plugin-specific command interface; can be NULL
    int function (int cmd, ...) command;

    // start is called to start plugin; can be NULL
    int function () start;

    // stop is called to deinit plugin; can be NULL
    int function () stop;

    // connect is called to setup connections between different plugins
    // it is called after all plugin's start method was executed
    // can be NULL
    // NOTE for GUI plugin developers: don't initialize your widgets/windows in
    // the connect method. look for up-to-date information on wiki:
    // http://github.com/Alexey-Yakovenko/deadbeef/wiki/Porting-GUI-plugins-to-deadbeef-from-0.5.x-to-0.6.0
    int function () connect;

    // opposite of connect, will be called before stop, while all plugins are still
    // in "started" state
    int function () disconnect;

    // exec_cmdline may be called at any moment when user sends commandline to player
    // can be NULL if plugin doesn't support commandline processing
    // cmdline is 0-separated list of strings, guaranteed to have 0 at the end
    // cmdline_size is number of bytes pointed by cmdline
    int function (const(char)* cmdline, int cmdline_size) exec_cmdline;

    // @returns linked list of actions for the specified track
    // when it is NULL -- the plugin must return list of all actions
    DB_plugin_action_t* function (DB_playItem_t* it) get_actions;

    // mainloop will call this function for every plugin
    // so that plugins may handle all events;
    // can be NULL
    int function (uint id, uintptr_t ctx, uint p1, uint p2) message;

    // plugin configuration dialog is constructed from this data
    // can be NULL
    const(char)* configdialog;
}

alias DB_plugin_t = DB_plugin_s;

// file format stuff

// channel mask - combine following flags to tell streamer which channels are
// present in input/output streams
enum
{
    DDB_SPEAKER_FRONT_LEFT = 1,
    DDB_SPEAKER_FRONT_RIGHT = 2,
    DDB_SPEAKER_FRONT_CENTER = 4,
    DDB_SPEAKER_LOW_FREQUENCY = 8,
    DDB_SPEAKER_BACK_LEFT = 16,
    DDB_SPEAKER_BACK_RIGHT = 32,
    DDB_SPEAKER_FRONT_LEFT_OF_CENTER = 64,
    DDB_SPEAKER_FRONT_RIGHT_OF_CENTER = 128,
    DDB_SPEAKER_BACK_CENTER = 256,
    DDB_SPEAKER_SIDE_LEFT = 512,
    DDB_SPEAKER_SIDE_RIGHT = 1024,
    DDB_SPEAKER_TOP_CENTER = 2048,
    DDB_SPEAKER_TOP_FRONT_LEFT = 4096,
    DDB_SPEAKER_TOP_FRONT_CENTER = 8192,
    DDB_SPEAKER_TOP_FRONT_RIGHT = 16384,
    DDB_SPEAKER_TOP_BACK_LEFT = 32768,
    DDB_SPEAKER_TOP_BACK_CENTER = 65536,
    DDB_SPEAKER_TOP_BACK_RIGHT = 131072
}

struct DB_fileinfo_s
{
    DB_decoder_s* plugin;

    // these parameters should be set in decoder->open
    ddb_waveformat_t fmt;

    // readpos should be updated to current decoder time (in seconds)
    float readpos;

    // this is the (optional) file handle, that can be used by streamer to
    // request interruption of current read operation
    DB_FILE* file;
}

alias DB_fileinfo_t = DB_fileinfo_s;

enum
{
    // Decoders should try to output 16 bit stream when this flag is set, for
    // performance reasons.
    DDB_DECODER_HINT_16BIT = 1,

    // Decoders should only call the streamer_set_bitrate from plugin.read function,
    // and only when this flag is set.
    DDB_DECODER_HINT_NEED_BITRATE = 2,
    // Decoders can do their own infinite looping when this flag is set, in the
    // "Loop Single" looping mode.
    DDB_DECODER_HINT_CAN_LOOP = 4
}

// decoder plugin
struct DB_decoder_s
{
    DB_plugin_t plugin;

    DB_fileinfo_t* function (uint hints) open;

    // init is called to prepare song to be started
    int function (DB_fileinfo_t* info, DB_playItem_t* it) init;

    // free is called after decoding is finished
    void function (DB_fileinfo_t* info) free;

    // read is called by streamer to decode specified number of bytes
    // must return number of bytes that were successfully decoded (sample aligned)
    int function (DB_fileinfo_t* info, char* buffer, int nbytes) read;

    int function (DB_fileinfo_t* info, float seconds) seek;

    // perform seeking in samples (if possible)
    // return -1 if failed, or 0 on success
    // if -1 is returned, that will mean that streamer must skip that song
    int function (DB_fileinfo_t* info, int sample) seek_sample;

    // 'insert' is called to insert new item to playlist
    // decoder is responsible to calculate duration, split it into subsongs, load cuesheet, etc
    // after==NULL means "prepend before 1st item in playlist"
    DB_playItem_t* function (ddb_playlist_t* plt, DB_playItem_t* after, const(char)* fname) insert;

    int function (DB_fileinfo_t* info) numvoices;
    void function (DB_fileinfo_t* info, int voice, int mute) mutevoice;

    int function (DB_playItem_t* it) read_metadata;
    int function (DB_playItem_t* it) write_metadata;

    // NULL terminated array of all supported extensions
    // examples:
    // { "aac", "wma", "tak", NULL } -- supports 3 file extensions
    // since API 1.9: { "*", NULL } -- supports any file extensions
    const(char*)* exts;

    // NULL terminated array of all supported prefixes (UADE support needs that)
    // e.g. "mod.song_title"
    const(char*)* prefixes;

    // This function's purpose is to open the file, so that the file handle is
    // immediately accessible via DB_fileinfo_t, and can be used with fabort.
    // If a plugin is using open2, it should not reopen the file from init.
    // Plugins _must_ implement open even if open2 is present,
    // because existing code may rely on it.
    DB_fileinfo_t* function (uint hints, DB_playItem_t* it) open2;
}

alias DB_decoder_t = DB_decoder_s;

// output plugin
struct DB_output_s
{
    DB_plugin_t plugin;
    // init is called once at plugin activation
    int function () init;
    // free is called if output plugin was changed to another, or unload is about to happen
    int function () free;
    // reconfigure output to another format
    int function (ddb_waveformat_t* fmt) setformat;
    // play, stop, pause, unpause are called by deadbeef in response to user
    // events, or as part of streaming process
    int function () play;
    int function () stop;
    int function () pause;
    int function () unpause;
    // one of output_state_t enum values
    int function () state;
    // soundcard enumeration (can be NULL)
    void function (void function (const(char)* name, const(char)* desc, void*) callback, void* userdata) enum_soundcards;

    // parameters of current output
    ddb_waveformat_t fmt;

    // set to 1 if volume control is done internally by plugin
    int has_volume;
}

alias DB_output_t = DB_output_s;

// dsp plugin
// see also: examples/dsp_template.c in git

struct ddb_dsp_context_s
{
    // pointer to DSP plugin which created this context
    DB_dsp_s* plugin;

    // pointer to the next DSP plugin context in the chain
    ddb_dsp_context_s* next;

    // read only flag; set by DB_dsp_t::enable
    uint enabled;
}

alias ddb_dsp_context_t = ddb_dsp_context_s;

struct DB_dsp_s
{
    DB_plugin_t plugin;

    ddb_dsp_context_t* function () open;

    void function (ddb_dsp_context_t* ctx) close;

    // samples are always interleaved floating point
    // returned value is number of output frames (multichannel samples)
    // plugins are allowed to modify channels, samplerate, channelmask in the fmt structure
    // buffer size can fit up to maxframes frames
    // by default ratio=1, and plugins don't need to touch it unless they have to
    int function (ddb_dsp_context_t* ctx, float* samples, int frames, int maxframes, ddb_waveformat_t* fmt, float* ratio) process;

    void function (ddb_dsp_context_t* ctx) reset;

    // num_params can be NULL, to indicate that plugin doesn't expose any params
    //
    // if num_params is non-NULL -- get_param_name, set_param and get_param must
    // all be implemented
    //
    // param names are for display-only, and are allowed to contain spaces
    int function () num_params;
    const(char)* function (int p) get_param_name;
    void function (ddb_dsp_context_t* ctx, int p, const(char)* val) set_param;
    void function (ddb_dsp_context_t* ctx, int p, char* str, int len) get_param;

    // config dialog implementation uses set/get param, so they must be
    // implemented if this is nonzero
    const(char)* configdialog;

    // since 1.1

    // can be NULL
    // should return 1 if the DSP plugin will not touch data with the current parameters;
    // 0 otherwise
    int function (ddb_dsp_context_t* ctx, ddb_waveformat_t* fmt) can_bypass;
}

alias DB_dsp_t = DB_dsp_s;

// misc plugin
// purpose is to provide extra services
// e.g. scrobbling, converting, tagging, custom gui, etc.
// misc plugins should be mostly event driven, so no special entry points in them
struct DB_misc_t
{
    DB_plugin_t plugin;
}

// vfs plugin
// provides means for reading, seeking, etc
// api is based on stdio
struct DB_vfs_s
{
    DB_plugin_t plugin;

    // capabilities
    const(char*)* function () get_schemes; // NULL-terminated list of supported schemes, e.g. {"http://", "ftp://", NULL}; can be NULL

    int function () is_streaming; // return 1 if the plugin streaming data over slow connection, e.g. http; plugins will avoid scanning entire files if this is the case

    int function (const(char)* fname) is_container; // should return 1 if this plugin can parse specified file

    // this allows interruption of hanging network streams
    void function (DB_FILE* stream) abort;

    // file access, follows stdio API with few extension
    DB_FILE* function (const(char)* fname) open;
    void function (DB_FILE* f) close;
    size_t function (void* ptr, size_t size, size_t nmemb, DB_FILE* stream) read;
    int function (DB_FILE* stream, long offset, int whence) seek;
    long function (DB_FILE* stream) tell;
    void function (DB_FILE* stream) rewind;
    long function (DB_FILE* stream) getlength;

    // should return mime-type of a stream, if known; can be NULL
    const(char)* function (DB_FILE* stream) get_content_type;

    // associates stream with a track, to allow dynamic metadata updating, like
    // in icy protocol
    void function (DB_FILE* f, DB_playItem_t* it) set_track;

    // folder access, follows dirent API, and uses dirent data structures
    int function (const(char)* dir, dirent*** namelist, int function (const(dirent)*) selector, int function (const(dirent*)*, const(dirent*)*) cmp) scandir;

    // returns URI scheme for a given file name, e.g. "zip://"
    // can be NULL
    // can return NULL
    const(char)* function (const(char)* fname) get_scheme_for_name;
}

alias DB_vfs_t = DB_vfs_s;

// gui plugin
// only one gui plugin can be running at the same time
// should provide GUI services to other plugins

// this structure represents a gui dialog with callbacks to set/get params
// documentation should be available here:
// http://github.com/Alexey-Yakovenko/deadbeef/wiki/GUI-Script-Syntax
struct ddb_dialog_t
{
    const(char)* title;
    const(char)* layout;
    void function (const(char)* key, const(char)* value) set_param;
    void function (const(char)* key, char* value, int len, const(char)* def) get_param;

    void* parent;
}

enum
{
    ddb_button_ok = 0,
    ddb_button_cancel = 1,
    ddb_button_close = 2,
    ddb_button_apply = 3,
    ddb_button_yes = 4,
    ddb_button_no = 5,
    ddb_button_max = 6
}

struct DB_gui_s
{
    DB_plugin_t plugin;

    // returns response code (ddb_button_*)
    // buttons is a bitset, e.g. (1<<ddb_button_ok)|(1<<ddb_button_cancel)
    int function (ddb_dialog_t* dlg, uint buttons, int function (int button, void* ctx) callback, void* ctx) run_dialog;
}

alias DB_gui_t = DB_gui_s;

// playlist plugin
struct DB_playlist_s
{
    DB_plugin_t plugin;

    DB_playItem_t* function (ddb_playlist_t* plt, DB_playItem_t* after, const(char)* fname, int* pabort, int function (DB_playItem_t* it, void* data) cb, void* user_data) load;

    // will save items from first to last (inclusive)
    // format is determined by extension
    // playlist is protected from changes during the call
    int function (ddb_playlist_t* plt, const(char)* fname, DB_playItem_t* first, DB_playItem_t* last) save;

    const(char*)* extensions; // NULL-terminated list of supported file extensions, e.g. {"m3u", "pls", NULL}

    // since 1.5

    DB_playItem_t* function (int visibility, ddb_playlist_t* plt, DB_playItem_t* after, const(char)* fname, int* pabort) load2;
}

alias DB_playlist_t = DB_playlist_s;

// __DEADBEEF_H
