#!/usr/bin/env python3
import os, re, subprocess, sys, tempfile
def strip(src, keep=None):
    return ''.join(text for text, _ in segments(src, keep))
def header_lines(src):
    lines = src.split('\n')
    n = 0
    for line in lines:
        if line.startswith('--'):
            n += 1
            continue
        break
    fields = ('-- name:', '-- description:', '-- incompatible:', '-- pausable:')
    if not any(line.startswith(fields) for line in lines[:n]):
        return 0
    return n
def keep_header(src, stripped):
    n = header_lines(src)
    if n == 0:
        return stripped
    head = src.split('\n')[:n]
    return '\n'.join(head) + '\n' + stripped.lstrip('\n')
def blanked(src, keep=None):
    return '\n'.join(line.rstrip() for line in strip(src, keep).split('\n'))
def segments(src, keep=None):
    out, i, n = [], 0, len(src)
    code = []
    def flush():
        if code:
            out.append((''.join(code), False)); code.clear()
    while i < n:
        c = src[i]
        if c == '[':
            j = i + 1; eq = 0
            while j < n and src[j] == '=':
                eq += 1; j += 1
            if j < n and src[j] == '[':
                close = ']' + '=' * eq + ']'
                end = src.find(close, j + 1)
                end = n if end == -1 else end + len(close)
                flush(); out.append((src[i:end], True)); i = end; continue
            code.append(c); i += 1; continue
        if c in '"\'':
            j = i + 1
            while j < n:
                if src[j] == '\\':
                    j += 2; continue
                if src[j] == c:
                    j += 1; break
                if src[j] == '\n':
                    break
                j += 1
            flush(); out.append((src[i:j], True)); i = j; continue
        if c == '-' and i + 1 < n and src[i + 1] == '-':
            j = i + 2
            if j < n and src[j] == '[':
                k = j + 1; eq = 0
                while k < n and src[k] == '=':
                    eq += 1; k += 1
                if k < n and src[k] == '[':
                    close = ']' + '=' * eq + ']'
                    end = src.find(close, k + 1)
                    end = n if end == -1 else end + len(close)
                    code.append('\n' * src.count('\n', i, end))
                    i = end; continue
            end = src.find('\n', i)
            end = n if end == -1 else end
            if keep is not None and keep(src[i:end]):
                code.append(src[i:end])
            i = end
            continue
        code.append(c); i += 1
    flush()
    return out
def tightened(src, keep=None):
    parts = []
    for text, is_string in segments(src, keep):
        if is_string:
            parts.append(text); continue
        lines = text.split('\n')
        head, tail = lines[:-1], lines[-1]
        kept, run = [], 0
        for line in head:
            line = line.rstrip()
            if line == '':
                run += 1
                if run > 1:
                    continue
            else:
                run = 0
            kept.append(line)
        kept.append(tail)
        parts.append('\n'.join(kept))
    out = ''.join(parts)
    return out.lstrip('\n').rstrip('\n') + '\n'
def strings_in(src):
    return [text for text, is_string in segments(src) if is_string]
TOOL_MARKERS = (re.compile(r"^--\s*(BEGIN|END)\s+[A-Z][A-Z0-9_]*\b"),
                re.compile(r"^--\s*[\w.-]+\.py:\s"))
def tool_marker(comment):
    return any(r.match(comment) for r in TOOL_MARKERS)
class LexError(ValueError):
    pass
_TOKEN = re.compile(r"""
    (?P<ws>[ \t\r\f\v\n]+)
  | (?P<comment>--\[(?P<ceq>=*)\[.*?\](?P=ceq)\]|--[^\n]*)
  | (?P<string>\[(?P<seq>=*)\[.*?\](?P=seq)\]
              |"(?:[^"\\\n]|\\.)*"
              |'(?:[^'\\\n]|\\.)*')
  | (?P<number>0[xX](?:[pP][+-]|[0-9A-Za-z._])*
              |(?:\d|\.\d)(?:[eE][+-]|[0-9A-Za-z._])*)
  | (?P<name>[A-Za-z_][A-Za-z0-9_]*)
  | (?P<op>\.\.\.|\.\.|==|~=|<=|>=|//|::|<<|>>|[-+*/%^\#&~|<>=(){}\[\];:,.])
""", re.S | re.X)
_LONG_OPEN = re.compile(r"\[=*\[")
def lex(src):
    out, i, n, line = [], 0, len(src), 1
    if src.startswith('#'):
        i = src.find('\n')
        i = n if i == -1 else i
    while i < n:
        m = _TOKEN.match(src, i)
        if m is None:
            what = ('unfinished string' if src[i] in '"\''
                    else 'no Lua token starts with %r' % src[i])
            raise LexError('line %d: %s' % (line, what))
        kind, text = m.lastgroup, m.group()
        if kind == 'comment' and m.group('ceq') is None \
                and _LONG_OPEN.match(src, i + 2):
            raise LexError('line %d: unfinished long comment' % line)
        if kind == 'op' and text == '[' and _LONG_OPEN.match(src, i):
            raise LexError('line %d: unfinished long string' % line)
        if kind != 'ws':
            out.append((kind, text, line))
        line += text.count('\n')
        i = m.end()
    return out
def code_tokens(src):
    return [(k, t) for k, t, _ in lex(src) if k != 'comment']
def luac_same(a_text, b_text):
    srcs, outs = [], []
    try:
        for text in (a_text, b_text):
            fd, p = tempfile.mkstemp(suffix='.lua'); os.close(fd)
            with open(p, 'w', encoding='utf-8') as f:
                f.write(text)
            srcs.append(p)
        for p in srcs:
            o = p + '.out'
            outs.append(o)
            r = subprocess.run(['luac', '-s', '-o', o, p],
                               capture_output=True, text=True)
            if r.returncode != 0:
                return False, 'luac refused: ' + (r.stderr.strip() or r.stdout.strip())
        with open(outs[0], 'rb') as f: a = f.read()
        with open(outs[1], 'rb') as f: b = f.read()
        return (a == b), ('identical' if a == b else
                          'bytecode differs (%d vs %d bytes)' % (len(a), len(b)))
    finally:
        for p in srcs + outs:
            try: os.unlink(p)
            except OSError: pass
USAGE = """Take the comments out of a Lua file, and prove that is all it did.

    tools/strip-comments.py --blank <file>     comments -> blank lines
    tools/strip-comments.py --tight <file>     ... and then collapse the gaps
    tools/strip-comments.py --check  <file>    prove --blank changed nothing

Writes to stdout. `--check` writes nothing and exits 0 or 1."""
def main():
    if len(sys.argv) != 3 or sys.argv[1] not in ('--blank', '--tight', '--check'):
        print(USAGE); return 2
    mode, path = sys.argv[1], sys.argv[2]
    src = open(path, encoding='utf-8').read()
    if mode == '--check':
        ok, why = luac_same(src, blanked(src))
        if ok:
            tight = tightened(src)
            before, after = strings_in(src), strings_in(tight)
            if before != after:
                ok = False
                for a, b in zip(before, after):
                    if a != b:
                        why = 'a string literal changed: %r became %r' % (
                            a[:60], b[:60])
                        break
                else:
                    why = 'string literals: %d before, %d after' % (
                        len(before), len(after))
            else:
                fd, tp = tempfile.mkstemp(suffix='.lua'); os.close(fd)
                try:
                    with open(tp, 'w', encoding='utf-8') as f:
                        f.write(tight)
                    r = subprocess.run(['luac', '-p', tp],
                                       capture_output=True, text=True)
                    if r.returncode != 0:
                        ok = False
                        why = 'tightened will not parse: ' + (
                            r.stderr.strip() or r.stdout.strip())
                    else:
                        why = 'identical, and %d string(s) survived tightening' % len(before)
                finally:
                    try: os.unlink(tp)
                    except OSError: pass
        print(('ok   ' if ok else 'FAIL ') + path + '  ' + why)
        return 0 if ok else 1
    out = blanked(src) if mode == '--blank' else tightened(src)
    sys.stdout.write(keep_header(src, out))
    return 0
if __name__ == '__main__':
    sys.exit(main())
