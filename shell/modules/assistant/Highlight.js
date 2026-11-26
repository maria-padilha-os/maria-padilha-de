.pragma library

var KEYWORDS = {
    python: "False None True and as assert async await break class continue def del elif else except finally for from global if import in is lambda nonlocal not or pass raise return try while with yield".split(" "),
    lua: "and break do else elseif end false for function goto if in local nil not or repeat return then true until while".split(" "),
    sh: "if then else elif fi for while do done case esac function in select until time coproc".split(" "),
    js: "async await break case catch class const continue debugger default delete do else export extends finally for function if import in instanceof let new of return static super switch this throw try typeof var void while with yield".split(" "),
    qml: "as id property signal function readonly required component on import pragma enum alias default".split(" "),
    c: "auto break case char const continue default do double else enum extern float for goto if inline int long register restrict return short signed sizeof static struct switch typedef union unsigned void volatile while".split(" "),
    cpp: "auto break case char class const constexpr continue default delete do double else enum explicit extern false float for friend goto if inline int long namespace new nullptr operator private protected public register return short signed sizeof static struct switch template this throw true try typedef typename union unsigned using virtual void volatile while".split(" "),
    rust: "as async await break const continue crate dyn else enum extern false fn for if impl in let loop match mod move mut pub ref return self Self static struct super trait true type unsafe use where while".split(" "),
    go: "break case chan const continue default defer else fallthrough for func go goto if import interface map package range return select struct switch type var".split(" "),
    sql: "select from where insert update delete into values set join left right inner outer on group by order having limit offset and or not null as distinct union all case when then else end".split(" ")
};

function normalize(lang) {
    var l = String(lang || "").toLowerCase();
    if (l === "py" || l === "python3")
        return "python";
    if (l === "bash" || l === "shell" || l === "zsh" || l === "console" || l === "root" || l === "sudo" || l === "privileged" || l === "sh-root")
        return "sh";
    if (l === "javascript" || l === "jsx" || l === "ts" || l === "typescript")
        return "js";
    if (l === "c++" || l === "cc" || l === "h" || l === "hpp")
        return "cpp";
    if (l === "rs")
        return "rust";
    if (l === "golang")
        return "go";
    if (l === "yml")
        return "yaml";
    return l;
}

function css(color) {
    var s = String(color);
    if (s.length === 9 && s.charAt(0) === "#")
        return "#" + s.substring(3);
    return s;
}

function esc(text) {
    return String(text).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

function keep(text) {
    return esc(text).replace(/\t/g, "    ").replace(/ /g, "&#160;").replace(/\n/g, "<br/>");
}

function span(color, text) {
    var c = color ? css(color) : "#e8eaed";
    return '<span style="color:' + c + '">' + keep(text) + "</span>";
}

function isKeyword(lang, word) {
    var words = KEYWORDS[lang];
    return words !== undefined && words.indexOf(word) !== -1;
}

function commentLength(code, i, lang) {
    var rest = code.slice(i);
    var line = "";
    if (lang === "python" || lang === "sh" || lang === "ruby" || lang === "yaml" || lang === "toml")
        line = "#";
    else if (lang === "lua" || lang === "sql")
        line = "--";

    if (lang === "js" || lang === "qml" || lang === "c" || lang === "cpp" || lang === "rust" || lang === "go" || lang === "java") {
        if (rest.indexOf("//") === 0) {
            var n = code.indexOf("\n", i);
            return (n < 0 ? code.length : n) - i;
        }
        if (rest.indexOf("/*") === 0) {
            var e = code.indexOf("*/", i + 2);
            return (e < 0 ? code.length : e + 2) - i;
        }
    }

    if (lang === "html" || lang === "xml") {
        if (rest.indexOf("<!--") === 0) {
            var h = code.indexOf("-->", i + 4);
            return (h < 0 ? code.length : h + 3) - i;
        }
    }

    if (line !== "" && rest.indexOf(line) === 0) {
        var n2 = code.indexOf("\n", i);
        return (n2 < 0 ? code.length : n2) - i;
    }
    return 0;
}

function stringLength(code, i) {
    var c = code.charAt(i);
    if (c !== '"' && c !== "'" && c !== "`")
        return 0;

    if (c !== "`" && code.substr(i, 3) === c + c + c) {
        var triple = code.indexOf(c + c + c, i + 3);
        return triple < 0 ? code.length - i : triple + 3 - i;
    }

    var j = i + 1;
    while (j < code.length) {
        var ch = code.charAt(j);
        if (ch === "\\") {
            j += 2;
            continue;
        }
        if (ch === c)
            return j + 1 - i;
        if (ch === "\n" && c !== "`")
            return j - i;
        j++;
    }
    return code.length - i;
}

function highlight(code, lang, streaming, palette) {
    var p = palette || {};
    var textColor = css(p.text || "#e8eaed");
    if (streaming)
        return '<span style="color:' + textColor + '">' + keep(code) + "</span>";

    var l = normalize(lang);
    var out = "";
    var i = 0;

    while (i < code.length) {
        var clen = commentLength(code, i, l);
        if (clen > 0) {
            out += span(p.comment || p.text, code.substr(i, clen));
            i += clen;
            continue;
        }

        var slen = stringLength(code, i);
        if (slen > 0) {
            out += span(p.string || p.text, code.substr(i, slen));
            i += slen;
            continue;
        }

        var rest = code.slice(i);
        var num = rest.match(/^(?:0x[0-9a-fA-F]+|\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)/);
        if (num !== null) {
            out += span(p.number || p.text, num[0]);
            i += num[0].length;
            continue;
        }

        var word = rest.match(/^[A-Za-z_][A-Za-z0-9_]*/);
        if (word !== null) {
            var w = word[0];
            var kind = "";
            if (isKeyword(l, w)) {
                kind = "keyword";
            } else {
                var j = i + w.length;
                while (j < code.length && /\s/.test(code.charAt(j)))
                    j++;
                if (code.charAt(j) === "(")
                    kind = "function";
                else if (/^[A-Z]/.test(w))
                    kind = "type";
            }
            out += kind === "" ? keep(w) : span(p[kind] || p.text, w);
            i += w.length;
            continue;
        }

        var ws = rest.match(/^\s+/);
        if (ws !== null) {
            out += keep(ws[0]);
            i += ws[0].length;
            continue;
        }

        out += keep(code.charAt(i));
        i++;
    }

    return '<span style="color:' + textColor + '">' + out + "</span>";
}
