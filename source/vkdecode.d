module vkdecode;

import std.stdio, std.math, std.string, std.array, std.conv, std.range, std.algorithm;

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
            } else if (cmd == "s") {
                tstr = vk_s(tstr, to!long(arg));
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
        result ~= to!string(to!char(currCh ^ ch));
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
                result ~= to!char(0xFF & (i >> shift));
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

            result ~= vk_str2[offset];
        } else {
            result ~= s;
        }
    }
    return result;
}

long[] vk_s_child(string t, long e) {
    long i = t.length;

    if (i == 0) {
        return [];
    }

    long[] o = [];

    foreach (a; iota(i - 1, -1, -1)) {
        e = abs(e) + a + i;
        o ~= e % i | 0;
    }
    reverse(o);
    return o;
}

string vk_s(string t, long e) {
    long i = t.length;

    if (i == 0) {
        return "";
    }

    long[] o = vk_s_child(t, e);
    string[] q = split(t, "");

    foreach (a; iota(1, i)) {
        auto y = q.splice(o[i - 1 - a], 1, [q[a]]);
        q[a] = y[0];
    }
    return q.join("");
}
// thanks to BioD
import core.stdc.string;
void replaceSlice2(T, U)(ref T[] s, in U[] slice, in T[] replacement)
    if (is(Unqual!U == T)) 
{

    auto offset = slice.ptr - s.ptr;
    auto slicelen = slice.length;
    auto replen = replacement.length;

    auto newlen = s.length - slicelen + replen;

    if (slicelen == replen) {
        s[offset .. offset + slicelen] = replacement;
        return;
    }

    if (replen < slicelen) {
        // overwrite piece of slice
        s[offset .. offset + replen] = replacement;
        // and then move the remainder
        memmove(s.ptr + (offset + replen),
                s.ptr + (offset + slicelen),
                (newlen - offset - replen) * T.sizeof);

        s.length = newlen;
        return;
    }

    // replen > slicelen
    s.length = newlen;
    // here, first move the remainder
    memmove(s.ptr + (offset + replen),
            s.ptr + (offset + slicelen),
            (newlen - offset - replen) * T.sizeof);
    // and then overwrite
    s[offset .. offset + replen] = replacement;
}

T[] splice(T)(ref T[] list, sizediff_t start, sizediff_t count, T[] objects=null) {
    T[] deletedRange = list[start..start+count].dup;
    replaceSlice2(list, list[start..start+count], objects);
    return deletedRange;
}