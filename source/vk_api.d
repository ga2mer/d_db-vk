module vk_api;
import deadbeefl;
import requests;
import std.regex, std.json, std.stdio, std.string;
import arsd.characterencodings;

__gshared DB_functions_t* deadbeef_api;

JSONValue vk_api_request(string method, string[string] args, bool isArray = false) {
    deadbeef_api.conf_lock();
    string session = cast(string)(deadbeef_api.conf_get_str_fast("dvk.session".toStringz, "noep".toStringz)).fromStringz;
    deadbeef_api.conf_unlock();
    auto rq = Request();
    rq.addHeaders(["Cookie": "remixsid=%s;".format(session),
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/59.0.3071.115 Safari/537.36"
    ]);
    auto rs = rq.post("https://vk.com/al_audio.php", args);
    try {
        auto r = regex(`\{.*\}`);
        if(isArray) {
            r = regex(`\[.*\]`);
        }
        string html = convertToUtf8(cast(immutable(ubyte)[])rs.responseBody.data, "windows1251");
        import std.algorithm : find;
        if(!html.find("<!json>").empty) {
            auto m = html.matchAll(r);
            JSONValue j = parseJSON(m.front[0]);
            return j;
        } else {
            writeln("reauth");
            vk_auth();
            return vk_api_request(method, args);
        }
    } catch(Throwable o) {
        writeln(o);
    }
    return `{}`.parseJSON;
}

void vk_auth() {
    auto rq = Request();
    //rq.cookie;
    rq.addHeaders([
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/59.0.3071.115 Safari/537.36"
    ]);
    deadbeef_api.conf_lock();
    string login = cast(string)(deadbeef_api.conf_get_str_fast("dvk.login".toStringz, "noep".toStringz)).fromStringz;
    string password = cast(string)(deadbeef_api.conf_get_str_fast("dvk.password".toStringz, "noep".toStringz)).fromStringz;
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
        string html = cast(string)rs.responseBody.data;
        auto ip_h_rx = regex(`<input type="hidden" name="ip_h" value="(.*)"`);
        auto lg_h_rx = regex(`<input type="hidden" name="lg_h" value="(.*)"`);
        auto ip_h = html.matchAll(ip_h_rx).front[1];
        auto lg_h = html.matchAll(lg_h_rx).front[1];
        form.add(formData("ip_h", ip_h));
        form.add(formData("lg_h", lg_h));
        auto rsLogin = rq.exec!"POST"("https://login.vk.com/?act=login", form);
        auto id_rx = `"uid":"(\d*)"`.regex;
        string login_html = cast(string)rsLogin.responseBody.data;
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