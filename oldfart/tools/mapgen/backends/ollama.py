import json
import urllib.error
import urllib.request
from . import Unavailable, BadReply, schema as schemamod
RECOMMENDED = ("qwen3:8b", "gemma3:12b", "qwen3:14b", "qwen3:4b", "gemma3:4b")
PULL_HINT = "ollama pull %s" % RECOMMENDED[0]
NUM_CTX_MIN = 4096
NUM_CTX_STEP = 2048
NUM_CTX_MAX = 32768
ANSWER_TOKENS = 1536
def http(method, url, body=None, timeout=10.0):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method,
                                 headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode("utf-8") or "{}")
    except urllib.error.HTTPError as why:
        try:
            msg = json.loads(why.read().decode("utf-8")).get("error")
        except Exception:
            msg = None
        raise Unavailable("HTTP %d%s" % (why.code, ": %s" % msg if msg else ""))
    except (urllib.error.URLError, OSError, TimeoutError) as why:
        reason = getattr(why, "reason", why)
        raise Unavailable("not running at %s (%s) - start it with: ollama serve"
                          % (url.split("/api/")[0], reason))
    except ValueError:
        raise BadReply("the answer was not JSON")
def models(config, transport=None):
    t = transport or http
    got = t("GET", config.ollama_url + "/api/tags", None, min(config.timeout, 5.0))
    return [m.get("name") for m in (got or {}).get("models", []) if m.get("name")]
def _installed(want, names):
    if want in names:
        return want
    if want + ":latest" in names:
        return want + ":latest"
    return None
def pick(names, want=""):
    if want:
        return _installed(want, names), "chosen in Preferences"
    for r in RECOMMENDED:
        got = _installed(r, names)
        if got:
            return got, "recommended for a 12 GB card"
    return (names[0], "the first installed model - %s is recommended" % RECOMMENDED[0]) \
        if names else (None, "")
def show(config, model, transport=None):
    t = transport or http
    try:
        got = t("POST", config.ollama_url + "/api/show", {"model": model},
                min(config.timeout, 5.0))
    except (Unavailable, BadReply):
        return {}
    return got if isinstance(got, dict) else {}
def context_of(info):
    mi = (info or {}).get("model_info") or {}
    for k, v in mi.items():
        if k.endswith(".context_length") and isinstance(v, int) and v > 0:
            return v
    return None
def thinks(info, model):
    caps = (info or {}).get("capabilities")
    if isinstance(caps, list):
        return "thinking" in caps
    return False
def num_ctx_for(messages, limit=None):
    need = sum(schemamod.tokens_estimate(m.get("content") or "") + 8 for m in messages)
    want = need + ANSWER_TOKENS
    n = max(NUM_CTX_MIN, -(-want // NUM_CTX_STEP) * NUM_CTX_STEP)
    cap = min(NUM_CTX_MAX, limit) if limit else NUM_CTX_MAX
    if want > cap:
        raise Unavailable("the prompt needs about %d tokens but the model holds %d - it would "
                          "be cut, so it was not sent" % (want, cap))
    return min(n, cap), need
class Session:
    def __init__(self, config, transport=None, prompts=None):
        if prompts is None:
            prompts = {"slim": schemamod.slim_prompt}
        self.prompts = dict({"system": schemamod.system_prompt, "schema": schemamod.schema,
                             "user": schemamod.user_prompt}, **prompts)
        self.config = config
        self.transport = transport or http
        self.usage = {}
        self.messages = []
        self.notes = []
        names = models(config, self.transport)
        if not names:
            raise Unavailable("no model installed - for example: %s" % PULL_HINT)
        self.model, how = pick(names, config.ollama_model)
        if self.model is None:
            raise Unavailable("the model %s is not installed (installed: %s)"
                              % (config.ollama_model, ", ".join(names[:6])))
        info = show(config, self.model, self.transport)
        self.context = context_of(info)
        self.think = thinks(info, self.model)
        if not config.ollama_model:
            self.notes.append("Ollama model %s (%s)" % (self.model, how))
    def _system(self, text, offline_raw):
        slim = self.prompts.get("slim")
        return slim(text, offline_raw) if slim else self.prompts["system"]()
    def ask(self, text, offline_raw=None, base=None, problems=None):
        if problems and self.messages:
            self.messages.append({"role": "user",
                                  "content": self.prompts["user"](text, problems=problems)})
        else:
            self.messages = [{"role": "system", "content": self._system(text, offline_raw)},
                             {"role": "user",
                              "content": self.prompts["user"](text, offline_raw, base)}]
        num_ctx, need = num_ctx_for(self.messages, self.context)
        body = {"model": self.model, "messages": self.messages, "stream": False,
                "format": self.prompts["schema"](),
                "options": {"temperature": 0, "num_ctx": num_ctx}}
        if self.think:
            body["think"] = False
        got = self.transport("POST", self.config.ollama_url + "/api/chat", body,
                             self.config.timeout)
        for k in ("prompt_eval_count", "eval_count"):
            if isinstance(got, dict) and isinstance(got.get(k), int):
                self.usage[k] = self.usage.get(k, 0) + got[k]
        self.usage["num_ctx"] = num_ctx
        seen = (got or {}).get("prompt_eval_count")
        if isinstance(seen, int) and seen >= num_ctx - 16:
            raise Unavailable("the prompt was cut: the model read %d tokens, the whole %d-token "
                              "window (the prompt needs about %d)" % (seen, num_ctx, need))
        msg = (got or {}).get("message") or {}
        content = msg.get("content") or ""
        self.messages.append({"role": "assistant", "content": content})
        if (got or {}).get("done_reason") == "length":
            raise BadReply("the answer was cut off")
        try:
            return json.loads(content)
        except ValueError:
            raise BadReply("not JSON")
def status(config, transport=None):
    from . import Status
    try:
        names = models(config, transport)
    except (Unavailable, BadReply) as why:
        return Status("ollama", False, "Ollama: not running", str(why))
    if not names:
        return Status("ollama", False, "Ollama: no model",
                      "running, but no model installed - %s" % PULL_HINT)
    model, how = pick(names, config.ollama_model)
    if model is None:
        return Status("ollama", False, "Ollama: model missing",
                      "%s is not installed (installed: %s)"
                      % (config.ollama_model, ", ".join(names[:6])))
    return Status("ollama", True, "Ollama: reachable",
                  "%s at %s (%s)" % (model, config.ollama_url, how))
