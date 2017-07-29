module vkdecode;

import std.string, std.array, std.conv, std.range, std.algorithm;

string VK_STR = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMN0PQRSTUVWXYZO123456789+/=";

string decode(string link) {
    if (link.indexOf("audio_api_unavailable")) {
        auto vals = link.split("?extra=")[1].split("#");
        string tstr = vk_o(vals[0]);
        string[] ops_list = vk_o(vals[1]).split("\x09");
        reverse(ops_list);
        foreach (op_data; ops_list) {
            string[] arr = op_data.split('\x0b');
            string cmd = arr[0];
            string arg = "";
            if (arr.length > 1) {
                arg = arr[1];
            }
            if (cmd == "v") {
                tstr = to!string(tstr.retro);
            } else if (cmd == "r") {
                tstr = vk_r(tstr, to!long(arg));
            } else if (cmd == "x") {
                tstr = vk_xor(tstr, arg);
            }
        }
        return tstr;
    }
    return "";
}
string vk_xor(string str1, string str2) {
    string result;
    char ch = str2[0];
    for (int i = 0; i < str1.length; i++) {
        char currCh = str1[i];
        result = result ~ to!string(to!char(currCh ^ ch));
    }
    return result;
}

string vk_o(string str) {
    auto result = "";
    long index2 = 0;
    long i;
    foreach (s; str) {
        long index = VK_STR.indexOf(s);
        if (index != -1) {
            if (index2 % 4 != 0) {
                i = (i << 6) + index;
            } else {
                i = index;
            }
            if (index2 % 4 != 0) {
                index2 += 1;
                long shift = -2 * index2 & 6;
                result = result ~ to!char(0xFF & (i >> shift));
            } else {
                index2 += 1;
            }
        }
    }
    return result;
}

string vk_r(string str, long i) {
    string result = "";
    string vk_str2 = VK_STR ~ VK_STR;
    long vk_str2_len = vk_str2.length;
    foreach (s; str) {
        long index = vk_str2.indexOf(s);
        if (index != -1) {
            long offset = index - i;

            if (offset < 0) {
                offset += vk_str2_len;
            }

            result = result ~ vk_str2[offset];
        } else {
            result = result ~ s;
        }
    }
    return result;
}