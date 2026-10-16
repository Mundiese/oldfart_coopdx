import re
HEADER = re.compile(r"^-- (name|description):")
_LONG_OPEN = re.compile(r"\[(=*)\[")
def tokens(text):
    out = []
    i, n, start = 0, len(text), 0
    def flush(upto):
        if upto > start:
            out.append(("code", text[start:upto]))
    while i < n:
        c = text[i]
        if c == "-" and text.startswith("--", i):
            flush(i)
            m = _LONG_OPEN.match(text, i + 2)
            if m:
                close = "]" + m.group(1) + "]"
                end = text.find(close, m.end())
                end = n if end < 0 else end + len(close)
            else:
                end = text.find("\n", i)
                end = n if end < 0 else end
            out.append(("comment", text[i:end]))
            i = start = end
            continue
        if c in "\"'":
            flush(i)
            j = i + 1
            while j < n and text[j] != c:
                if text[j] == "\\":
                    j += 1
                elif text[j] == "\n":
                    break
                j += 1
            end = min(n, j + 1)
            out.append(("string", text[i:end]))
            i = start = end
            continue
        if c == "[":
            m = _LONG_OPEN.match(text, i)
            if m:
                flush(i)
                close = "]" + m.group(1) + "]"
                end = text.find(close, m.end())
                end = n if end < 0 else end + len(close)
                out.append(("string", text[i:end]))
                i = start = end
                continue
        i += 1
    flush(n)
    return out
def comments(text):
    return [t for k, t in tokens(text) if k == "comment"]
def strip(text, keep_header=False):
    head = []
    if keep_header:
        lines = text.split("\n")
        while lines and HEADER.match(lines[0]):
            head.append(lines.pop(0))
        text = "\n".join(lines)
    pieces = []
    for kind, part in tokens(text):
        if kind == "comment":
            if part.startswith("--[") and _LONG_OPEN.match(part, 2):
                pieces.append((" ", False))
            continue
        pieces.append((part, kind == "string"))
    lines, cur, began = [], [], False
    for part, in_string in pieces:
        segs = part.split("\n")
        cur.append(segs[0])
        for seg in segs[1:]:
            lines.append(("".join(cur), began, in_string))
            cur, began = [seg], in_string
    lines.append(("".join(cur), began, False))
    out = []
    for line, began, ends in lines:
        if ends:
            out.append(line)
            continue
        line = line.rstrip()
        if began or line.strip():
            out.append(line)
    body = "\n".join(out)
    return "\n".join(head + ([body] if body else [])) + "\n"
