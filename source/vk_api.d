module vk_api;

import deadbeefl;
import requests;
import std.conv, std.regex, std.json, std.stdio, std.string;
import arsd.characterencodings;

__gshared DB_functions_t* deadbeef_api;

string UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/59.0.3071.115 Safari/537.36";

int search_target_id = 0;

JSONValue vk_api_request(string method, string[string] args, bool putOid = false) {
    deadbeef_api.conf_lock();

    string session = to!string(deadbeef_api.conf_get_str_fast("dvk.session".toStringz, "noep".toStringz).fromStringz);

    deadbeef_api.conf_unlock();

    auto rq = Request();

    rq.addHeaders([
        "Cookie": "remixsid=%s;".format(session),
        "User-Agent": UA
    ]);

    auto rs = rq.post("https://vk.com/%s.php".format(method), args);
    try {
        string html = convertToUtf8(cast(immutable(ubyte)[])rs.responseBody.data, "windows1251");
        auto r = regex(`\[.*\]`);
        auto m = html.matchAll(r);
        m.popFront();
        JSONValue j = parseJSON(m.hit);
        switch (j[1].type) {
            case JSON_TYPE.FALSE:
                return `{}`.parseJSON;
            case JSON_TYPE.STRING:
                if(j[1].str.startsWith("ERR_")) {
                    return `{}`.parseJSON;
                } else {
                    writeln("no auth");
                    vk_auth();
                    if(putOid) {
                        deadbeef_api.conf_lock();
                        string id = cast(string)(deadbeef_api.conf_get_str_fast("dvk.id".toStringz, "0".toStringz)).fromStringz;
                        deadbeef_api.conf_unlock();
                        args["owner_id"] = id;
                    }
                    return vk_api_request(method, args);
                }
            case JSON_TYPE.ARRAY:
            case JSON_TYPE.OBJECT:
                return j[1];
            default:
                break;
        }
    } catch(Throwable o) {
        writeln(o);
    }
    return `{}`.parseJSON;
}

JSONValue[] vk_my_music_request() {
    deadbeef_api.conf_lock();
    string id = cast(string)(deadbeef_api.conf_get_str_fast("dvk.id".toStringz, "0".toStringz)).fromStringz;
    deadbeef_api.conf_unlock();

    auto rs = vk_api_request("al_audio", [
        "act": "load_section",
        "al": "-1",
        "claim": "0",
        "is_loading_all": "1",
        "owner_id": id,
        "playlist_id": "-1",
        "type": "playlist"
    ], true);
    return rs["list"].array;
}

JSONValue[] vk_search_request(string query) {
    auto rs = vk_api_request("al_audio", [
        "act": "load_section",
        "al": "-1",
        "is_loading_all": "1",
        "playlist_id": "-1",
        "type": "search",
        "search_q": query,
        "search_performer": to!string(search_target_id)
    ]);

    return rs["list"].array;
}

JSONValue[] vk_get_by_id(string link) {

    auto rx = `https:\/\/vk\.com\/(.*)\/?$`.regex;

    auto m = link.matchAll(rx);

    auto content = getContent("https://api.vk.com/method/utils.resolveScreenName?screen_name=%s".format(m.front[1]));

    auto s = to!string(content).parseJSON;

    long owner_id = s["response"]["object_id"].integer;

    if(s["response"]["type"].str == "group") {
        owner_id = -owner_id;
    }

    auto rs = vk_api_request("al_audio", [
        "act": "load_section",
        "al": "-1",
        "claim": "0",
        "is_loading_all": "1",
        "owner_id": to!string(owner_id),
        "playlist_id": "-1",
        "type": "playlist"
    ], true);

    return rs["list"].array;
}

JSONValue[] vk_suggested_request() {
    auto rs = vk_api_request("al_audio", [
        "act": "load_section",
        "al": "-1",
        "claim": "0",
        "is_loading_all": "1",
        "playlist_id": "recoms1",
        "type": "recoms"
    ]);

    return rs["list"].array;
}

string vk_open_request(string id) {
    auto rs = vk_api_request("al_audio", [
        "act": "reload_audio",
        "al": "-1",
        "ids": id
    ]);
    return rs[0][2].str;
}

void vk_auth() {
    auto rq = Request();

    rq.addHeaders([
        "User-Agent": UA
    ]);

    deadbeef_api.conf_lock();

    string login = to!string(deadbeef_api.conf_get_str_fast("dvk.login".toStringz, "noep".toStringz));
    string password = to!string(deadbeef_api.conf_get_str_fast("dvk.password".toStringz, "noep".toStringz));

    deadbeef_api.conf_unlock();

    MultipartForm form;
    form.add(formData("act", "login"));
    form.add(formData("role", "al_frame"));
    form.add(formData("expire", ""));
    form.add(formData("captcha_sid", ""));
    form.add(formData("captcha_key", ""));
    form.add(formData("_origin", "https://vk.com"));
    form.add(formData("email", login));
    form.add(formData("pass", password));

    try {
        auto rs = rq.exec!"GET"("https://vk.com/login?m=1&email=login");
        string html = to!string(rs.responseBody);
        auto ip_h_rx = regex(`<input type="hidden" name="ip_h" value="(.*)"`);
        auto lg_h_rx = regex(`<input type="hidden" name="lg_h" value="(.*)"`);
        auto ip_h = html.matchAll(ip_h_rx).front[1];
        auto lg_h = html.matchAll(lg_h_rx).front[1];
        form.add(formData("ip_h", ip_h));
        form.add(formData("lg_h", lg_h));
        auto rsLogin = rq.exec!"POST"("https://login.vk.com/?act=login", form);
        auto id_rx = `"uid":"(\d*)"`.regex;
        string login_html = to!string(rsLogin.responseBody);
        string id = login_html.matchAll(id_rx).front[1];
        string cookie = "";
        foreach(e; rq.cookie) {
            if(e[2] == "remixsid") {
                cookie = e[3];
            }
        }
        if(!cookie.empty) {
            writeln(cookie);
            deadbeef_api.conf_set_str("dvk.session".toStringz, cookie.toStringz);
            deadbeef_api.conf_set_str("dvk.id".toStringz, id.toStringz);
            deadbeef_api.conf_save();
            writeln("writed");
        }
    } catch(Throwable e) {
        writeln(e);
    }
}

void initAPI(DB_functions_t* deadbeef) {
    deadbeef_api = deadbeef;
}

bool hasHQ(long flags) {
    return (flags & 16) == 16;
}

string HQ_formatted(long flags) {
    bool has_hq = hasHQ(flags);
    if(has_hq) {
        return "HQ";
    } else {
        return "";
    }
}
